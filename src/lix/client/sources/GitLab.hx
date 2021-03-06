package lix.client.sources;

class GitLab {

  public function intercept(url:Url)
    return return switch url {
      case { scheme: 'https', host: { name: 'gitlab.com' }, path: _.parts()[0] == 'api' => false }:
        Some(processUrl(url));
      default:
        None;
    }

  public function schemes()
    return ['gitlab'];

  var privateToken:String;
  public function new(?privateToken:String = '') {
    this.privateToken = switch privateToken.trim() {
      case '': '';
      case v: 'private_token=$v';
    }
  }
  
  static function host(?options:{ ?host:String })
    return switch options {
      case null | { host: null }: 'gitlab.com';
      case { host: v }: v;
    }

  public function grabCommit(owner, project, version, ?options:{ ?host:String })
    return Download.text('https://${host(options)}/api/v4/projects/$owner%2F$project/repository/commits/$version?$privateToken')
      .next(function (s)          
        try {
          var parsed:Dynamic = s.parse();
          if(version == '') parsed = parsed[0];
          return(parsed.id:String);
        } catch (e:Dynamic) {
          var s = switch version {
            case null | '': '';
            case v: '#$v';
          }
          
          return new Error('Failed to lookup sha for gitlab:$owner/$project$s');
        }
      );
  
  public function getArchive(owner:String, project:String, ?commitish:String, ?options:{ ?host:String }):Promise<ArchiveJob> 
    return switch commitish {
      case null: 
        grabCommit(owner, project, '', options).next(getArchive.bind(owner, project, _, options));
      case sha if (sha.length == 40):
        var url = 'https://${host(options)}/api/v4/projects/$owner%2F$project/repository/archive.zip?sha=$sha&${privateToken}';
        return ({
          normalized: url,
          dest: Computed(function (l) return [l.name, l.version, 'gitlab', sha]),
          url: url,
          lib: { name: Some(project), version: None }, 
        } : ArchiveJob);
      case v:
        grabCommit(owner, project, v, options).next(getArchive.bind(owner, project, _, options));
    }
    
  public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid gitlab url $url');
      case _.parts().toStringArray() => [owner, project]: getArchive(owner, Git.strip(project), url.hash, { host: url.host });
      default: new Error('invalid gitlab url $url');
    }
}
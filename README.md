<p>
 A lightweight web based application to manage VoIP systems based on Freswitch.<br> 	
 This solution is mainly suitable to manage small PBX systems with few domains and about 1k users, 
 possible to work on quite old systems and doesn't require any external packages (exclude SQLite, see installation guide).<br>
 The backend was writtenin Perl, frondend - javascript/qooxdoo.<br>
</p>

## Version-1.1
 - support multi-tenant configuration
 - support the whole xmlcurl bindings (configuration, directory, dialplan)
 - manage domains, users, profiles, dialplan and configurations
 - manage voip devices and provide auto configuration service [ACS] (templates based)
 - manage registrations and calls
 - simple files manager for: scrips, sounds, recordings and user files
 - powerful editor for: scrips (lua/javascript) and xml documents (sip profiles, modules and dialplans)
 - event socket console and journal viewer
 - pure perl event-socket client
 - json-rpc api
  
## Manuals
 - [Installation guide](https://github.com/akscf/fsadmin/blob/main/docs/fsadmin_1x_installation_guide.pdf)
 - [API documentation](https://github.com/akscf/fsadmin/blob/main/docs/fsadmin_1x_api.pdf)



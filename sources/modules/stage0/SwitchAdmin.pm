# *********************************************************************************************************************************
# base on: fsmgmt-2.5-10082008
#
# Copyright (C) AlexandrinKS
# https://akscf.me/
# *********************************************************************************************************************************
package SwitchAdmin;

use Log::Log4perl;
use Wstk::WstkException;
use Wstk::WstkDefs qw(RPC_ERR_CODE_INTERNAL_ERROR);

use SwitchAdmin::Defs;
use SwitchAdmin::SQLite;
use SwitchAdmin::CacheManager;
use SwitchAdmin::SecurityManager;

use SwitchAdmin::DAO::SystemDAO;
use SwitchAdmin::DAO::SipDomainDAO;
use SwitchAdmin::DAO::SipUserDAO;
use SwitchAdmin::DAO::SipUserGroupDAO;
use SwitchAdmin::DAO::SipUserHomeDirDAO;
use SwitchAdmin::DAO::SipDeviceDAO;
use SwitchAdmin::DAO::SipDeviceLineDAO;
use SwitchAdmin::DAO::SipProfileDAO;
use SwitchAdmin::DAO::SipGatewayDAO;
use SwitchAdmin::DAO::SipContextDAO;
use SwitchAdmin::DAO::SipContextBodyDAO;
use SwitchAdmin::DAO::SipCidProfileDAO;
use SwitchAdmin::DAO::DocTemplateDAO;
use SwitchAdmin::DAO::DocTemplateBodyDAO;
use SwitchAdmin::DAO::SwitchConfigDAO;
use SwitchAdmin::DAO::SwitchModuleDAO;
use SwitchAdmin::DAO::SwitchScriptDAO;
use SwitchAdmin::DAO::SwitchRecordingDAO;
use SwitchAdmin::DAO::SwitchSoundDAO;
use SwitchAdmin::DAO::SwitchMiscDAO;
use SwitchAdmin::DAO::SipCidProfileDAO;

use SwitchAdmin::Services::AuthenticationService;
use SwitchAdmin::Services::SipDevicesManagementService;
use SwitchAdmin::Services::SipDeviceLinesManagementService;
use SwitchAdmin::Services::SipDomainsManagementService;
use SwitchAdmin::Services::SipUsersManagementService;
use SwitchAdmin::Services::SipUserGroupsManagementService;
use SwitchAdmin::Services::SipProfilesManagementService;
use SwitchAdmin::Services::SipGatewaysManagementService;
use SwitchAdmin::Services::SipContextsManagementService;
use SwitchAdmin::Services::TemplatesManagementService;
use SwitchAdmin::Services::SwitchManagementService;
use SwitchAdmin::Services::SystemInformationService;
use SwitchAdmin::Services::DriversManagementService;
use SwitchAdmin::Services::SwitchConfigsManagementService;
use SwitchAdmin::Services::SwitchModulesManagementService;
use SwitchAdmin::Services::SwitchScriptsManagementService;
use SwitchAdmin::Services::SwitchSoundsManagementService;
use SwitchAdmin::Services::SwitchRecordingsManagementService;
use SwitchAdmin::Services::SwitchEventSocketService;
use SwitchAdmin::Services::SwitchMiscellaneousService;
use SwitchAdmin::Services::SipUserHomeDirManagementService;
use SwitchAdmin::Services::SipCidProfilesManagementService;

use SwitchAdmin::Servlets::AcsServlet;
use SwitchAdmin::Servlets::BlobsHelperServlet;
use SwitchAdmin::Servlets::SwitchConfigurationServlet;

# -------------
use constant CONFIG_NAME => 'fsadmin';

sub new ($$;$) {
        my ($class) = @_;
        my $self = {
                logger      	=> Log::Log4perl::get_logger(__PACKAGE__),
                class_name  	=> $class,
                version     	=> 1.1,
                description 	=> "Freeswitch admin",
                start_time		=> time(),
                wstk         	=> undef,
                sec_mgr	    	=> undef,
                mapi 			=> undef,
                dbm 			=> undef,
				dao				=> {},
        };
        bless( $self, $class );
        return $self;
}

sub get_class_name {
	my ($self) = @_;
	return $self->{class_name};
}

#---------------------------------------------------------------------------------------------------------------------------------
sub init {
	my ($self, $wstk) = @_;
	$self->{'wstk'} = $wstk;
}

sub start {
	my ($self) = @_;

	$self->{'wstk'}->cfg_load(CONFIG_NAME, sub {            
		my $cfg = shift;
		die Wstk::WstkException->new("Missing configureation file!");
	});

	$self->{'mapi'}	= SwitchAdmin::MAPI->new($self);
	$self->{'wstk'}->mapi_register('SwitchAdmin', $self->{'mapi'});

	$self->{'sec_mgr'} = SwitchAdmin::SecurityManager->new($self);	
	$self->{'cache_mgr'} = SwitchAdmin::CacheManager->new($self);
	$self->{'dbm'} = SwitchAdmin::SQLite->new($self, 'fsadmin.db');

	# ------------------------------------------------------------------------------------------	
	$self->dao_register(SwitchAdmin::DAO::SystemDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipDomainDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipUserDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipUserGroupDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipUserHomeDirDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipDeviceDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipDeviceLineDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipProfileDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipGatewayDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipContextBodyDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipContextDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SipCidProfileDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::DocTemplateBodyDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::DocTemplateDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SwitchConfigDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SwitchModuleDAO->new($self));	
	$self->dao_register(SwitchAdmin::DAO::SwitchScriptDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SwitchSoundDAO->new($self));
	$self->dao_register(SwitchAdmin::DAO::SwitchRecordingDAO->new($self));	
	$self->dao_register(SwitchAdmin::DAO::SwitchMiscDAO->new($self));	
			
	$self->{'wstk'}->mapper_alias_register('FileItem', SwitchAdmin::Models::FileItem::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('ServerStatus', SwitchAdmin::Models::ServerStatus::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('DocTemplate', SwitchAdmin::Models::DocTemplate::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('DocTemplateBody', SwitchAdmin::Models::DocTemplateBody::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipDevice', SwitchAdmin::Models::SipDevice::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipDeviceLine', SwitchAdmin::Models::SipDeviceLine::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipDomain', SwitchAdmin::Models::SipDomain::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipUser', SwitchAdmin::Models::SipUser::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipUserGroup', SwitchAdmin::Models::SipUserGroup::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipProfile', SwitchAdmin::Models::SipProfile::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipGateway', SwitchAdmin::Models::SipGateway::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipContext', SwitchAdmin::Models::SipContext::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipContextBody', SwitchAdmin::Models::SipContextBody::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SwitchConfig', SwitchAdmin::Models::SwitchConfig::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SwitchModule', SwitchAdmin::Models::SwitchModule::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SipCidProfile', SwitchAdmin::Models::SipCidProfile::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('DriverInfo', SwitchAdmin::Models::DriverInfo::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SwitchCodecInfo', SwitchAdmin::Models::SwitchCodecInfo::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SwitchUserRegInfo', SwitchAdmin::Models::SwitchUserRegInfo::CLASS_NAME);
	$self->{'wstk'}->mapper_alias_register('SwitchCallInfo', SwitchAdmin::Models::SwitchCallInfo::CLASS_NAME);
	
	$self->{'wstk'}->rpc_service_register('AuthenticationService', SwitchAdmin::Services::AuthenticationService->new($self));	
	$self->{'wstk'}->rpc_service_register('SwitchManagementService', SwitchAdmin::Services::SwitchManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('DriversManagementService', SwitchAdmin::Services::DriversManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SystemInformationService', SwitchAdmin::Services::SystemInformationService->new($self));	
	$self->{'wstk'}->rpc_service_register('SipDevicesManagementService', SwitchAdmin::Services::SipDevicesManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipDeviceLinesManagementService', SwitchAdmin::Services::SipDeviceLinesManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipDomainsManagementService', SwitchAdmin::Services::SipDomainsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipUsersManagementService', SwitchAdmin::Services::SipUsersManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipUserGroupsManagementService', SwitchAdmin::Services::SipUserGroupsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipUserHomeDirManagementService', SwitchAdmin::Services::SipUserHomeDirManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipProfilesManagementService', SwitchAdmin::Services::SipProfilesManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipGatewaysManagementService', SwitchAdmin::Services::SipGatewaysManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipContextsManagementService', SwitchAdmin::Services::SipContextsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('TemplatesManagementService', SwitchAdmin::Services::TemplatesManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SipCidProfilesManagementService', SwitchAdmin::Services::SipCidProfilesManagementService->new($self));	
	$self->{'wstk'}->rpc_service_register('SwitchConfigsManagementService', SwitchAdmin::Services::SwitchConfigsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SwitchModulesManagementService', SwitchAdmin::Services::SwitchModulesManagementService->new($self));	
	$self->{'wstk'}->rpc_service_register('SwitchScriptsManagementService', SwitchAdmin::Services::SwitchScriptsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SwitchSoundsManagementService', SwitchAdmin::Services::SwitchSoundsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SwitchRecordingsManagementService', SwitchAdmin::Services::SwitchRecordingsManagementService->new($self));
	$self->{'wstk'}->rpc_service_register('SwitchMiscellaneousService', SwitchAdmin::Services::SwitchMiscellaneousService->new($self));	
	$self->{'wstk'}->rpc_service_register('SwitchEventSocketService', SwitchAdmin::Services::SwitchEventSocketService->new($self));	
	
	$self->{'wstk'}->servlet_register('/acs/*', SwitchAdmin::Servlets::AcsServlet->new($self));
	$self->{'wstk'}->servlet_register('/blobs/*', SwitchAdmin::Servlets::BlobsHelperServlet->new($self));
	$self->{'wstk'}->servlet_register('/switch/*', SwitchAdmin::Servlets::SwitchConfigurationServlet->new($self));
	#$self->{'wstk'}->servlet_register('/upload/*', SwitchAdmin::Servlets::UploadHelperServlet->new($self));	
	#	
	$self->{logger}->debug("fsadmin is ready (version ".$self->{version}.")");
	
	# start freeswitch manually
	if(get_config($self, 'freeswitch', 'start_switch_manually') eq 'true') {
		my $cmd = get_config($self, 'freeswitch','cmd_start');
    	unless($cmd) {
        	$self->{logger}->warn("Missing property: freeswitch.cmd_start");
    	} else {
    		$self->{logger}->debug("staring freeswitch...");
			system($cmd);
			my $res = $?;
    		if ($res == -1) {
        		my $err = $!;
        		$self->{logger}->error("Couldn't start freeswitch: ".$err);
        	}
    	}
	}
}

sub stop {
	my ($self) = @_;
}

#---------------------------------------------------------------------------------------------------------------------------------
sub get_config {
	my ($self, $section, $property) = @_;
	my $wstk = $self->{wstk}; 
	return $wstk->cfg_get(CONFIG_NAME, $section, $property);
}

sub driver_lookup {
	my ($self, $name, $quiet) = @_;
	my $mapi = $self->{'mapi'};
	return $mapi->driver_lookup($name, $quiet);
}

sub drivers_list {
	my ($self) = @_;
	my $mapi = $self->{'mapi'};
	return $mapi->drivers_list();
}

sub dao_register {
	my ($self, $inst) = @_;
    my $dao = $self->{dao};
    #
    unless($inst) {
		die Wstk::WstkException->new("Invalid argument: inst");
	}
	my @t = split('::', $inst->get_class_name());
	my $sz = scalar(@t);
	my $name = ($sz > 0 ? $t[$sz - 1] : $inst->get_class_name());
	#
	if(exists($dao->{$name})) {
		die Wstk::WstkException->new("Duplicate DAO: ".$name);
	}
	$dao->{$name} = $inst;
}

sub dao_lookup {
	my ($self, $name, $quiet) = @_;
	my $dao = $self->{dao};
	#
	unless(exists($dao->{$name})) {
		return undef if ($quiet);
		die Wstk::WstkException->new("Unknown DAO: ".$name);
	}
	return $dao->{$name};
}

#---------------------------------------------------------------------------------------------------------------------------------
{
	package SwitchAdmin::MAPI;
	use SwitchAdmin::Models::DriverInfo;

	sub new ($$;$) {
		my ($class, $fsadmin) = @_;
		my $self = {
			class_name  => $class,
			logger 		=> Log::Log4perl::get_logger(__PACKAGE__),
			fsadmin		=> $fsadmin,
			drivers     => {}
		};
		bless($self, $class);
		return $self;
	}

	sub get_class_name {
		my ($self) = @_;
		return $self->{class_name};
	}

	sub get_api_version {
		my ($self) = @_;
		return 1.0;
	}

	sub dao_lookup {
		my ($self, $name, $quiet) = @_;
		return $self->{'fsadmin'}->dao_lookup($name, $quiet);
	}

	sub drivers_list {
		my ($self) = @_;
		my $drv_list = [];
		my $drivers = $self->{'drivers'};
		foreach my $key (keys %{$drivers}) {
			my $e = $drivers->{$key};
			push(@{$drv_list}, $e->{'info'});
		}
		return $drv_list;
	}

	sub driver_lookup {
		my ($self, $name, $quiet) = @_;
    	unless($name) {
			die Wstk::WstkException->new("Invalid argument: name");
		}
		my $drivers = $self->{'drivers'};
		unless(exists($drivers->{$name})) {
			return undef if ($quiet);
			die Wstk::WstkException->new("Unknown driver: ".$name);
		}
		my $e = $drivers->{$name};
		return $e->{'driver'};
	}

	sub driver_register {
		my ($self, $driver_info, $inst) = @_;
    	unless($driver_info || $driver_info->{name}) {
			die Wstk::WstkException->new("Invalid argument: driver_info");
		}
		my $name = $driver_info->name();
		my $drivers = $self->{'drivers'};
		if(exists($drivers->{$name})) {
			die Wstk::WstkException->new("Duplicate driver: ".$name);
		}
		$drivers->{$name} = {info => $driver_info, driver => $inst };
		$self->{'logger'}->debug('Driver registered: '.$name);
	}

	sub driver_unregister {
		my ($self, $name) = @_;
    	unless($name) {
			die Wstk::WstkException->new("Invalid argument: name");
		}
		my $drivers = $self->{'drivers'};
		delete($drivers->{$name});
		$self->{'logger'}->debug('Driver unregistered: '.$name);
	}
}
#---------------------------------------------------------------------------------------------------------------------------------
return SwitchAdmin->new();


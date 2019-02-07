%% service_info
%% Information of the servie
-record(state, {dns_list,node_list,application_list,
		dns_info,dns_addr}).

-define(WANTED_NUM_INSTANCES,2).

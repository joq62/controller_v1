%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : dbase using dets 
%%%
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(controller_lib).
 


%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("controller/src/controller_local.hrl").

-include("include/tcp.hrl").
-include("include/dns.hrl").
-include("include/dns_data.hrl").
-include("include/kubelet_data.hrl").
-include("include/loader.hrl").
%% --------------------------------------------------------------------

%% External exports
-compile(export_all).

%-export([load_start_node/3,stop_unload_node/3
%	]).


%% ====================================================================
%% External functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
nice_print([AvailableServices,NeededServices,StartResult,SurplusServices,Nodes])->
    % Availible services dns info  ServiceId, Vsn , IpAddr , Port
  %  io:format("Nice print:AvailableServices ~n"),
    
   io:format("~n"),  
    io:format("**********************>>  "),
    io:format("~p",[{time()}]),
    io:format("   <<******************* ~n"),
   io:format("~n"),
    case Nodes of
	[]->
	    io:format("No nodes are availible ~n");
	_->
	    L2=[{KInfo#kubelet_info.ip_addr,KInfo#kubelet_info.port,KInfo#kubelet_info.zone,KInfo#kubelet_info.capabilities,KInfo#kubelet_info.node_type}||KInfo<-Nodes],
	    io:format("Available nodes: ~p~n",[L2])
    end,
   io:format("~n"),
    case AvailableServices of
	[]->
	    io:format("No services are availible ~n");
	_->
	    L1=[{DnsInfo#dns_info.service_id,DnsInfo#dns_info.ip_addr,DnsInfo#dns_info.port}||DnsInfo<-AvailableServices],
	    io:format("AvailableServices: ~p~n",[L1])
    end,
   io:format("~n"),
    case NeededServices of
	[]->
	    io:format("No needed services ~n");
	_->
	    io:format("Needed services ~p~n",[NeededServices])
    end,
   io:format("~n"),
   case StartResult of
	[]->
	    io:format("No services to start ~n");
	_->
	   io:format("Services to start ~p~n",[{StartResult}])
	  % L3=[{ServiceId,Vsn,Num}||{{ServiceId,Vsn},Num}<-ServicesToStart,false==(Num=:=0)],
	  % io:format("Services to start ~p~n",[L3])
    end,
    io:format("~n"),
   case SurplusServices of
	[]->
	    io:format("No surplus services ~n");
	_->
	    io:format("Surplus services to stop ~p~n",[SurplusServices])
    end,
    io:format("-------------------  End --------------------------- ~n"),
   io:format("~n"),
    ok.
    
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
campaign(State)->
    io:format(" State#state.application_list  ~p~n",[{?MODULE,?LINE,time(),State#state.application_list}]),
    NeededServices=controller_lib:needed_applications(State#state.application_list,State),
    io:format(" NeededServices  ~p~n",[{?MODULE,?LINE,time(),NeededServices}]),
 
 %   io:format(" AvailableServices  ~p~n",[{?MODULE,?LINE,time(),AvailableServices}]),

    StartResult=controller_lib:load_start_services(NeededServices,?WANTED_NUM_INSTANCES,State),
    io:format("StartResult  ~p~n",[{?MODULE,?LINE,time(),StartResult}]),

    %keep system services repo, catalog, controller
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    AvailableServices=if_dns:call("dns",{dns,get_all_instances,[]},{DnsIp,DnsPort}), 
    io:format(" AvailableServices  ~p~n",[{?MODULE,?LINE,AvailableServices}]),
    L1=keep_system_services([?KEEP_SYSTEM_SERVICES],AvailableServices),
    SurplusServices=controller_lib:surplus_services(NeededServices,L1),
    io:format(" SurplusServices  ~p~n",[{?MODULE,?LINE,SurplusServices}]),
    _StopResult=controller_lib:stop_applications(SurplusServices,AvailableServices,State),
    controller_lib:nice_print([AvailableServices,NeededServices,StartResult,SurplusServices,State#state.node_list]),
    ok.

keep_system_services([],WorkerService)->
    [DnsInfo#dns_info.service_id||DnsInfo<-WorkerService];
keep_system_services([ServiceId|T],Acc)->
    NewAcc=[DnsInfo||DnsInfo<-Acc,
		     false==(DnsInfo#dns_info.service_id==ServiceId)],
    keep_system_services(T,NewAcc). 


surplus_services([],SurplusServices)->
    io:format(" glurk SurplusServices  ~p~n",[{?MODULE,?LINE,SurplusServices}]),  
    SurplusServices;
%surplus_services([X_DnsInfo|T],Acc)->
surplus_services(X,Acc)->
    io:format(" X,Acc  ~p~n",[{?MODULE,?LINE,X,Acc}]),  
    [X_DnsInfo|T]=X,
    io:format(" X_DnsInfo,Acc  ~p~n",[{?MODULE,?LINE,X_DnsInfo,Acc}]),
    NewAcc=[DnsInfo||DnsInfo<-Acc,
		     false==({DnsInfo#dns_info.service_id}==
				 {X_DnsInfo#dns_info.service_id})],
    surplus_services(T,NewAcc).


%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
node_register(KubeletInfo, State) ->
    TimeStamp=erlang:now(),
    NewKubeletInfo=KubeletInfo#kubelet_info{time_stamp=TimeStamp},
    #kubelet_info{time_stamp=_,ip_addr=IpAddr,port=Port,service_id=ServiceId,
		  max_workers=_MaxWorkers,zone=_Zone,capabilities=_Capabilities,
		  node_type=_
		 }=KubeletInfo,
    X1=[X||X<-State#state.node_list,false==({IpAddr,Port,ServiceId}==
				  {X#kubelet_info.ip_addr,X#kubelet_info.port,X#kubelet_info.service_id})],
    NewKubeletList=[NewKubeletInfo|X1],
    NewState=State#state{node_list=NewKubeletList},
    NewState.

de_node_register(KubeletInfo, State) ->
    #dns_info{time_stamp=_,ip_addr=IpAddr,port=Port,service_id=ServiceId}=KubeletInfo,
    NewKubeletList=[X||X<-State#state.node_list,
		       false==({IpAddr,Port,ServiceId}==
				   {X#kubelet_info.ip_addr,X#kubelet_info.port,X#kubelet_info.service_id})],
    NewState=State#state{node_list=NewKubeletList},
    NewState.
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
stop_applications([],DnsList,_State)->
    DnsList;
stop_applications([ApplicationId|T],DnsList,State)->
    io:format(" ApplicationId ~p~n",[{?MODULE,?LINE,ApplicationId}]),
    ListWithIp=[{DnsInfo#dns_info.ip_addr,DnsInfo#dns_info.port,
		 DnsInfo#dns_info.service_id,DnsInfo}||DnsInfo<-DnsList,
						       ApplicationId=:=DnsInfo#dns_info.service_id],
    io:format(" stop_services ListWithIp  ~p~n",[{?MODULE,?LINE,ListWithIp}]),
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    _StopResult=do_stop(ListWithIp,{DnsIp,DnsPort},[]),
    NewDnsList=[Y_DnsInfo||Y_DnsInfo<-DnsList,
			   false==(ApplicationId=:=Y_DnsInfo#dns_info.service_id)],
    stop_applications(T,NewDnsList,State).

do_stop([],_,StopResult)->
    StopResult;
do_stop([{IpAddr,Port,ApplicationId,DnsInfo}|T],{DnsIp,DnsPort},Acc)->
    Stop=ssl_lib:ssl_call([{IpAddr,Port}],{kubelet,stop_service,[ApplicationId]}),
    NewAcc=[{ApplicationId,{IpAddr,Port},Stop}|Acc],
    do_stop(T,{DnsIp,DnsPort},NewAcc).
    
						  

%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
which_to_stop(AppId,Vsn,NewAppList,JoscaInfo,State)->
    AllApplications=rpc:call(node(),controller_lib,needed_applications,[NewAppList,State]),
   io:format(" AllApplications  ~p~n",[{?MODULE,?LINE,AllApplications}]),

%   Get which applications that needs to be removed
    AppIdServices=rpc:call(node(),controller_lib,needed_applications,[[{{AppId,Vsn},JoscaInfo}],State]),

   io:format(" AppIdServices  ~p~n",[{?MODULE,?LINE,AppIdServices}]),
    
    ApplicationToStop=[X_ApplicationId||X_ApplicationId<-AppIdServices,
					false==lists:member(X_ApplicationId,AllApplications)],
    ServicesToDeRegister=which_services_de_reg(ApplicationToStop,[]),
%    io:format(" ApplicationToStop  ~p~n",[{?MODULE,?LINE,ApplicationToStop}]),
    io:format(" ApplicationToStop,ServicesToDeRegister  ~p~n",[{?MODULE,?LINE,ApplicationToStop,ServicesToDeRegister}]),
    {ApplicationToStop,ServicesToDeRegister}.


which_services_de_reg([],ServicesToDeRegister)->
    ServicesToDeRegister;
which_services_de_reg([ApplicationId|T],Acc) ->
     FileName=filename:join([?JOSCA,ApplicationId++".josca"]),
    case file:consult(FileName) of
	{error,Err}->
	    {error,[?MODULE,?LINE,Err,FileName]},
	    io:format("~p~n",[{error,[?MODULE,?LINE,Err,FileName]}]),
	    NewAcc=[{error,[?MODULE,?LINE,Err,FileName]}|Acc];
	{ok,JoscaInfo}->
	    {exported_services,ExportedServices}=lists:keyfind(exported_services,1,JoscaInfo),
	    NewAcc=lists:append(ExportedServices,Acc)
    end,
    which_services_de_reg(T,NewAcc).

%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
needed_applications(ApplicationList,State)->
   % io:format(" ApplicationList  ~p~n",[{?MODULE,?LINE,time(),ApplicationList}]),
    needed_applications(ApplicationList,State,[]).

needed_applications([],_,NeededServices)->
  %  io:format(" NeededServices  ~p~n",[{?MODULE,?LINE,time(),NeededServices}]),
    NeededServices;
needed_applications([{{AppId,Vsn},JoscaFile}|T],State,Acc)->
 %   io:format(" {{AppId,vsn},JoscaFile}  ~p~n",[{?MODULE,?LINE,time(),{{AppId,Vsn},JoscaFile}}]),
    {dependencies,ApplicationList}=lists:keyfind(dependencies,1,JoscaFile),
  %  io:format(" ServiceList ~p~n",[{?MODULE,?LINE,ApplicationList}]),
    NewAcc=check_applications(ApplicationList,State,Acc),
  %  io:format(" NewAcc  ~p~n",[{?MODULE,?LINE,time(),NewAcc}]),
    needed_applications(T,State,NewAcc).

check_applications([],_,Acc)->
    Acc;
check_applications([Id|T],State,Acc) ->
    NewAcc=case josca:start_order(Id,State) of
	       {error,Err}->
		   io:format("error~p~n",[{?MODULE,?LINE,Err}]),
		   Acc;
	       ApplicationId ->
		   case lists:member(Id,Acc) of
		       true->
			   Acc;
		       false->
			   %lists:append(Services,Acc)
			   [ApplicationId|Acc]
		   end
	   end,
    check_applications(T,State,NewAcc).



missing_services(NeededServices,DnsList)->
    AvailibleServices=[{DnsInfo#dns_info.service_id}||DnsInfo<-DnsList],
    [{Id}||{Id}<-NeededServices, 
			       lists:member({Id},AvailibleServices)=:=false].
    
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
load_start_services(NeededServices,WantedNumInstances,State)->
  %  io:format(" NeededServices,WantedNumInstances  ~p~n",[{?MODULE,?LINE,NeededServices,WantedNumInstances}]),
    %% 1. Collect all service instances
    %% 2. For each service collect allready deployed instances
    %% 3. Remove Nodes that already have deployed the service from available node list 
    %% 4. Calculate how many missing instances there are per service
    %% 5. Start missing instances, based on the updaetd nodelist 
    % 1.
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    AllAvailableServices=if_dns:call("dns",{dns,get_all_instances,[]},{DnsIp,DnsPort}),
  %  io:format(" AllAvailableServices  ~p~n",[{?MODULE,?LINE,AllAvailableServices}]),
    % 2.
    AlreadyAvailableServiceInstances=[{ServiceId,DnsInfo}||ServiceId<-NeededServices,
					       DnsInfo<-AllAvailableServices,
					       DnsInfo#dns_info.service_id=:=ServiceId],
   % io:format(" AlreadyAvailableServiceInstances  ~p~n",[{?MODULE,?LINE,AlreadyAvailableServiceInstances}]),
    % 3.
    FilteredAvailableNodeList=get_nodes_deploy_to(NeededServices,AlreadyAvailableServiceInstances,WantedNumInstances,State),
 %   io:format(" FilteredAvailableNodeList  ~p~n",[{?MODULE,?LINE,time(),FilteredAvailableNodeList}]),
    % 4.
    %ServiceNumToStart=calc_num_start(NeededServices,FilteredAvailableNodeList),
    
    % 5.
    StartResult=schedule_start(NeededServices,FilteredAvailableNodeList,WantedNumInstances,[]),
  %  io:format(" StartResult  ~p~n",[{?MODULE,?LINE,time(),StartResult}]),
    
    StartResult.
       

get_nodes_deploy_to(NeededServices,AlreadyAvailableServiceInstances,WantedNumInstances,State)->
  %  io:format("AlreadyAvailableServiceInstances,State  ~p~n",[{?MODULE,?LINE,AlreadyAvailableServiceInstances,State}]),
    GitJoscaServices=State#state.git_url++?JOSCA++".git",
    os:cmd("git clone "++GitJoscaServices),
    FilteredAvailableNodeList=get_nodes_deploy_to(NeededServices,AlreadyAvailableServiceInstances,WantedNumInstances,State,[]),
    FilteredAvailableNodeList.

get_nodes_deploy_to([],_,_,_,FilteredAvailableNodeList)->
  %  io:format("FilteredAvailableNodeList  ~p~n",[{?MODULE,?LINE,FilteredAvailableNodeList}]),
    FilteredAvailableNodeList;

get_nodes_deploy_to([ServiceIdToDeploy|T],AlreadyAvailableServiceInstances,WantedNumInstances,State,Acc)->
    FileName=filename:join([?JOSCA,ServiceIdToDeploy++".josca"]),
 %  io:format(" FileName  ~p~n",[{?MODULE,?LINE,time(),FileName}]),
    case file:consult(FileName) of
	{error,Err}->
	    NewAcc=[{error,Err}|Acc],
	    io:format("~p~n",[{?MODULE,?LINE,'error',Err}]),
	    {error,[?MODULE,?LINE,Err]};
	{ok,JoscaInfo}->
	   %  io:format("JoscaInfo  ~p~n",[{?MODULE,?LINE,JoscaInfo}]),
	    {zone,WantedZone}=lists:keyfind(zone,1,JoscaInfo),
	    {needed_capabilities,WantedCapabilities}=lists:keyfind(needed_capabilities,1,JoscaInfo),
	    {num_instances,NumWantedInstances}=lists:keyfind(num_instances,1,JoscaInfo),
	    AllNodesFullfilledNeeds=get_nodes_fullfills_needs(WantedZone,WantedCapabilities,State#state.node_list),
	    
	    ExistingServiceInstances=[{DnsInfo#dns_info.ip_addr,DnsInfo#dns_info.port}||{ServiceId,DnsInfo}<-AlreadyAvailableServiceInstances,
				     ServiceIdToDeploy=:=ServiceId],
	    NumInstances=lists:flatlength(ExistingServiceInstances),
	    if 
		NumInstances>(NumWantedInstances-1) -> 
		    FilteredAvailableNodeList=[];
		
	        true-> % 
		    AvailableNodeList=[{ServiceIdToDeploy,{Node#kubelet_info.ip_addr,Node#kubelet_info.port}}
				       ||Node<-AllNodesFullfilledNeeds,
					 false=:=lists:member({Node#kubelet_info.ip_addr,Node#kubelet_info.port}
							     ,ExistingServiceInstances)],
		    FilteredAvailableNodeList=lists:sublist(AvailableNodeList,NumWantedInstances-NumInstances)
	    end,
%	    io:format("FilteredAvailableNodeList  ~p~n",[{?MODULE,?LINE,FilteredAvailableNodeList}]),
	    
	    NewAcc=lists:join(Acc,FilteredAvailableNodeList)
    end,
    get_nodes_deploy_to(T,AlreadyAvailableServiceInstances,WantedNumInstances,State,NewAcc).
	    
	    

schedule_start(_,_,0,StartResult)->
    StartResult;
schedule_start([],_,_,StartResult) ->
    StartResult;
schedule_start(_,[],_,StartResult) ->
    StartResult;
schedule_start([ServiceIdToStart|T],FilteredAvailableNodeList,WantedNumInstances,Acc)->
    % Check if there are enough og nodes
    NodesForService=[{ServiceId,{NodeIpAddr,NodePort}}||{ServiceId,{NodeIpAddr,NodePort}}<-FilteredAvailableNodeList,
							ServiceId=:=ServiceIdToStart],
    NumNodes=lists:flatlength(NodesForService),
    Diff=NumNodes-WantedNumInstances,
    StartResult=if
		    NumNodes =:= 0-> % Error No nodes avaialble 
			io:format("Error ~p~n",[{?MODULE,?LINE,'No nodes are availible for the service ',ServiceIdToStart}]),
			{error,[?MODULE,?LINE,'No nodes are availible for the service ',ServiceIdToStart]};
		    Diff < 0 -> % Ok To few nodes compare needed but nodes are availble , the list NodesForService limits num nodes started
			[ssl_lib:ssl_call([{NodeIpAddr,NodePort}],{kubelet,start_service,[ServiceId]})
			 ||{ServiceId,{NodeIpAddr,NodePort}}<-NodesForService];
		    Diff =:= 0-> % Ok  Need and wanted matches, , the list NodesForService limits num nodes started
			[ssl_lib:ssl_call([{NodeIpAddr,NodePort}],{kubelet,start_service,[ServiceId]})
			 ||{ServiceId,{NodeIpAddr,NodePort}}<-NodesForService];
	       Diff > 0 -> % Ok More nodes then needed, take a sublist to start
			SubList=lists:sublist(NodesForService,WantedNumInstances),
			[ssl_lib:ssl_call([{NodeIpAddr,NodePort}],{kubelet,start_service,[ServiceId]})
			 ||{ServiceId,{NodeIpAddr,NodePort}}<-SubList]		
		end,
    NewAcc=[{ServiceIdToStart,StartResult}|Acc],
    schedule_start(T,FilteredAvailableNodeList,WantedNumInstances,NewAcc).
	    
  


%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------



%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
get_nodes_fullfills_needs(WantedZone,WantedCapabilities,AvailibleNodes)->
    io:format("WantedZone,WantedCapabilities,AvailibleNodes  ~p~n",[{?MODULE,?LINE,WantedZone,WantedCapabilities,AvailibleNodes}]),
    % Which nodes is in needed zone
    Workers=[X_Node||X_Node<-AvailibleNodes,
		     X_Node#kubelet_info.node_type=:=worker_node],
    RightZone = case WantedZone of
		    []->
			Workers;
		    ZoneList ->
			[Zone]=ZoneList,
   			[Node||Node<-Workers,
			       lists:member(Zone,Node#kubelet_info.zone)]
		%		Node#kubelet_info.zone=:=Zone]
		end,
    NodesFullfilledNeeds=case WantedCapabilities of
			     []->
				 RightZone;
			     WantedCapabilities->
				 [Node||Node<-RightZone,
					check_capbility(WantedCapabilities,Node)]
			 end,
 %   io:format(" NodesFullfilledNeeds  ~p~n",[{?MODULE,?LINE,NodesFullfilledNeeds}]),
    NodesFullfilledNeeds.


check_capbility(WantedCapabilities,Node)->
    check_capbility(WantedCapabilities,Node,false).
    
check_capbility([],_,Boolean)->
    Boolean;
check_capbility([WCap|T],Node,_)->    
    case lists:member(WCap,Node#kubelet_info.capabilities) of
	false->
	    Tail=[],  % Stop searching
	    R=false;  % Failed
	true->
	    Tail=T,   % Continue search
	    R=true    % Succeded 
    end,
    check_capbility(Tail,Node,R).    
	   
				
    % Which nodes in needed zone has the right capabilities



%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------

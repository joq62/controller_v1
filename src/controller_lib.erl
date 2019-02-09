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
nice_print([AvailableServices,NeededServices,ServicesToStart,SurplusServices,Nodes])->
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
   case ServicesToStart of
	[]->
	    io:format("No services to start ~n");
	_->
	   L3=[{ServiceId,Vsn,Num}||{{ServiceId,Vsn},Num}<-ServicesToStart,false==(Num=:=0)],
	   io:format("Services to start ~p~n",[L3])
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
%    io:format(" State#state.application_list  ~p~n",[{?MODULE,?LINE,time(),State#state.application_list}]),
    NeededServices=controller_lib:needed_services(State#state.application_list,State),
 %   io:format(" NeededServices  ~p~n",[{?MODULE,?LINE,time(),NeededServices}]),
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    AvailableServices=if_dns:call("dns",{dns,get_all_instances,[]},{DnsIp,DnsPort}),
 %   io:format(" AvailableServices  ~p~n",[{?MODULE,?LINE,time(),AvailableServices}]),
    ServicesToStart=controller_lib:services_to_start(NeededServices,AvailableServices,?WANTED_NUM_INSTANCES),
 %   io:format(" ServicesToStart  ~p~n",[{?MODULE,?LINE,time(),ServicesToStart}]),
   case ServicesToStart of
	[]->
	    _StartResult=ok;
	ServicesToStart->
	    StartResult=controller_lib:start_services(ServicesToStart,State,[])
%	    io:format(" StartResult  ~p~n",[{?MODULE,?LINE,time(),StartResult}])
    end,
    
    %keep system services repo, catalog, controller
    L1=keep_system_services(["dns","controller"],AvailableServices),
    SurplusServices=controller_lib:surplus_services(NeededServices,L1),
 %   io:format(" SurplusServices  ~p~n",[{?MODULE,?LINE,time(),SurplusServices}]),
    _StopResult=controller_lib:stop_services(SurplusServices,AvailableServices,State),
    controller_lib:nice_print([AvailableServices,NeededServices,ServicesToStart,SurplusServices,State#state.node_list]),
    ok.

keep_system_services([],WorkerService)->
    [{DnsInfo#dns_info.service_id}||DnsInfo<-WorkerService];
keep_system_services([ServiceId|T],Acc)->
    NewAcc=[DnsInfo||DnsInfo<-Acc,
		     false==(DnsInfo#dns_info.service_id==ServiceId)],
    keep_system_services(T,NewAcc). 


surplus_services([],SurplusServices)->
    SurplusServices;
surplus_services([X_DnsInfo|T],Acc)->
    
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
stop_services([],DnsList,_State)->
    DnsList;
stop_services([{ServiceId}|T],DnsList,State)->
    ListWithIp=[{DnsInfo#dns_info.ip_addr,DnsInfo#dns_info.port,
		 DnsInfo#dns_info.service_id,DnsInfo}||DnsInfo<-DnsList,
						       {ServiceId}=:={DnsInfo#dns_info.service_id}],
  %  io:format(" stop_services ListWithIp  ~p~n",[{?MODULE,?LINE,time(),ListWithIp}]),
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    [{if_dns:cast("dns",{dns,de_dns_register,[DnsInfo]},{DnsIp,DnsPort}),
      tcp:test_call([{X_IpAddr,X_Port}],{kubelet,stop_service,[X_ServiceId]})}||{X_IpAddr,X_Port,X_ServiceId,DnsInfo}<-ListWithIp],
    
    
    NewDnsList=[Y_DnsInfo||Y_DnsInfo<-DnsList,
					   false==({ServiceId}=:={Y_DnsInfo#dns_info.service_id})],
    stop_services(T,NewDnsList,State).
						  
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
needed_services(ApplicationList,State)->
  %  io:format(" ApplicationList  ~p~n",[{?MODULE,?LINE,time(),ApplicationList}]),
    needed_services(ApplicationList,State,[]).

needed_services([],_,NeededServices)->
   % io:format(" NeededServices  ~p~n",[{?MODULE,?LINE,time(),NeededServices}]),
    NeededServices;
needed_services([{{AppId,Vsn},JoscaFile}|T],State,Acc)->
  %  io:format(" {{AppId,vsn},JoscaFile}  ~p~n",[{?MODULE,?LINE,time(),{{AppId,Vsn},JoscaFile}}]),
    {dependencies,ServiceList}=lists:keyfind(dependencies,1,JoscaFile),
    NewAcc=check_services(ServiceList,State,Acc),
   % io:format(" NewAcc  ~p~n",[{?MODULE,?LINE,time(),NewAcc}]),
    needed_services(T,State,NewAcc).

check_services([],_,Acc)->
    Acc;
check_services([{Id,_Vsn}|T],State,Acc) ->
    NewAcc=case josca:start_order(Id,State) of
	       {error,Err}->
		   io:format("error~p~n",[{?MODULE,?LINE,Err}]),
		   Acc;
	       Services ->
		   case lists:member({Id},Acc) of
		       true->
			   Acc;
		       false->
			   lists:append(Services,Acc)
		   end
	   end,
    check_services(T,State,NewAcc).


services_to_start(NeededServices,DnsList,WantedNumInstances)->
    AvailibleServices=[{DnsInfo#dns_info.service_id}||DnsInfo<-DnsList],
    calc_to_start(NeededServices,AvailibleServices,WantedNumInstances,[]). 
  
calc_to_start([],_,_,Acc)->
    Acc;
calc_to_start([{Id}|T],AvailibleServices,WantedNumInstances,Acc) ->
    L1=[{Id}||{A_ServiceId}<-AvailibleServices,
		  true==({A_ServiceId}=:={Id})],
    NumToStart=WantedNumInstances-lists:flatlength(L1),
  %  io:format(" NumToStart, L1  ~p~n",[{?MODULE,?LINE,time(),NumToStart,L1}]),
    NewAcc=[{{Id},NumToStart}|Acc],
    calc_to_start(T,AvailibleServices,WantedNumInstances,NewAcc).

missing_services(NeededServices,DnsList)->
    AvailibleServices=[{DnsInfo#dns_info.service_id}||DnsInfo<-DnsList],
    [{Id}||{Id}<-NeededServices, 
			       lists:member({Id},AvailibleServices)=:=false].
    
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------

start_services([],_,StartResult)->
    StartResult;
start_services([{{ServiceId},NumInstances}|T],State,Acc)->
  %  io:format(" ServiceId,Nodes  ~p~n",[{?MODULE,?LINE,time(),ServiceId}]),
    GitService=State#state.git_url++?JOSCA++".git",
    os:cmd("git clone "++GitService),
    FileName=filename:join([?JOSCA,ServiceId++".josca"]),
   % io:format(" FileName  ~p~n",[{?MODULE,?LINE,time(),FileName}]),
    case file:consult(FileName) of
	{error,Err}->
	    NewAcc=[{error,Err}|Acc],
	    io:format("~p~n",[{?MODULE,?LINE,'error',Err}]),
	    {error,[?MODULE,?LINE,Err]};
	{ok,JoscaInfo}->
	    {zone,WantedZone}=lists:keyfind(zone,1,JoscaInfo),
	    {needed_capabilities,WantedCapabilities}=lists:keyfind(needed_capabilities,1,JoscaInfo),
	    NodesFullfilledNeeds=get_nodes_fullfills_needs(WantedZone,WantedCapabilities,State#state.node_list),
	    case NodesFullfilledNeeds of
		[]->
		    NewAcc=[{error,['error no availible nodes',ServiceId]}|Acc];
		NodesFullfilledNeeds->
%		    io:format(" NumInstances  ~p~n",[{?MODULE,?LINE,time(),NumInstances}]),
		    R=schedule_start(ServiceId,NodesFullfilledNeeds,NumInstances),
		    NewAcc=[R|Acc]
	    end;
	Err ->
	    NewAcc=[{error,Err}|Acc],
	    io:format("~p~n",[{?MODULE,?LINE,'error',Err}]),
	     {error,[?MODULE,?LINE,Err]}
	    
    end,
    start_services(T,State,NewAcc).

%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
schedule_start(ServiceId,NodesFullfilledNeeds,NumInstances)->
    NumNodes=lists:flatlength(NodesFullfilledNeeds),
    Result=case NumNodes of
	       0->
		   io:format("Error ~p~n",[{?MODULE,?LINE,'No nodes are availible for the service ',ServiceId}]),
		   {error,[?MODULE,?LINE,'No nodes are availible for the service ',ServiceId]};
	       NumNodes ->
		   do_start(NodesFullfilledNeeds,NumInstances,ServiceId,[])
    end,
    Result.

do_start([],_,_,StartResult)-> % Less nodes then NodesFullfilledNeeds
    StartResult;
do_start(_,0,_,StartResult)->
      StartResult;
do_start([KubeleteInfo|T],NumInstances,ServicesId,Acc)->
    IpAddr=KubeleteInfo#kubelet_info.ip_addr,
    Port=KubeleteInfo#kubelet_info.port,
    StartResult=tcp:test_call([{IpAddr,Port}],{kubelet,start_service,[ServicesId]}),
 %   io:format(" StartResult  ~p~n",[{?MODULE,?LINE,time(),StartResult}]),
    case StartResult of
       {error,Err}->
	    io:format(" ~p~n",[{?MODULE,?LINE,time(),{error,Err}}]),
	    NewNumInstances=NumInstances;
	_->
	    NewNumInstances=NumInstances-1
    end,
  %  io:format(" NewNumInstances  ~p~n",[{?MODULE,?LINE,time(),NewNumInstances}]),
    NewAcc=[StartResult|Acc],
    do_start(T,NewNumInstances,ServicesId,NewAcc).



%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
get_nodes_fullfills_needs(WantedZone,WantedCapabilities,AvailibleNodes)->
    % Which nodes is in needed zone
    Workers=[X_Node||X_Node<-AvailibleNodes,
		     X_Node#kubelet_info.node_type=:=worker_node],
    RightZone = case WantedZone of
		    []->
			Workers;
		    Zone ->
   			[Node||Node<-Workers,
				Node#kubelet_info.zone=:=Zone]
		end,
    NodesFullfilledNeeds=case WantedCapabilities of
			     []->
				 RightZone;
			     WantedCapabilities->
				 [Node||Node<-RightZone,
					check_capbility(WantedCapabilities,Node)]
			 end,
    
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

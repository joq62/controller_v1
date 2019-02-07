%%% -------------------------------------------------------------------
%%% Author  : Joq Erlang
%%% Description : test application calc
%%% Created : 10 dec 2012
%%%
%%% -------------------------------------------------------------------
-module(controller).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("kube/controller/src/controller_local.hrl").

-include("kube/include/tcp.hrl").
-include("kube/include/dns.hrl").
-include("kube/include/dns_data.hrl").
-include("kube/include/data.hrl").
-include("kube/include/kubelet_data.hrl").
%% --------------------------------------------------------------------


%% --------------------------------------------------------------------
%% Key Data structures
%% 
%% --------------------------------------------------------------------
%-record(state, {applications,services,cluster_status}).

%%---------------------------------------------------------------------

-export([campaign/1,
	 add/2,remove/2,
	 get_all_applications/0,get_all_services/0,
	 all_nodes/0,
	 node_register/1,de_node_register/1
	]).

-export([start/0,
	 stop/0,
	 heart_beat/0
	]).

%% gen_server callbacks
-export([init/1, handle_call/3,handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% ====================================================================
%% External functions
%% ====================================================================

%% Gen server functions

start()-> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
stop()-> gen_server:call(?MODULE, {stop},infinity).



%%-----------------------------------------------------------------------

% Test


%% end test
campaign(Interval)->
    gen_server:call(?MODULE, {campaign,Interval},infinity).

heart_beat()->
    gen_server:call(?MODULE, {heart_beat},infinity).   
all_nodes()->
    gen_server:call(?MODULE, {all_nodes},infinity).

get_all_applications()->
    gen_server:call(?MODULE, {get_all_applications},infinity).

get_all_services()->
    gen_server:call(?MODULE, {get_all_services},infinity).
    
%%-----------------------------------------------------------------------
    
add(AppId,Vsn)->
    gen_server:call(?MODULE, {add,AppId,Vsn},infinity).  
remove(AppId,Vsn)->
    gen_server:call(?MODULE, {remove,AppId,Vsn},infinity). 
%%-----------------------------------------------------------------------



node_register(KubeletInfo)->
    gen_server:cast(?MODULE, {node_register,KubeletInfo}).
de_node_register(KubeletInfo)->
    gen_server:cast(?MODULE, {de_node_register,KubeletInfo}).

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%%
%% --------------------------------------------------------------------
init([]) ->
     {ok,MyIp}=application:get_env(ip_addr),
    {ok,Port}=application:get_env(port),
    {ok,ServiceId}=application:get_env(service_id),
    {ok,Vsn}=application:get_env(vsn),
    {ok,DnsIp}=application:get_env(dns_ip_addr),
    {ok,DnsPort}=application:get_env(dns_port),
     DnsInfo=#dns_info{time_stamp="not_initiaded_time_stamp",
			service_id = ServiceId,
			vsn = Vsn,
			ip_addr=MyIp,
			port=Port
		       },
    spawn(fun()-> local_heart_beat(?HEARTBEAT_INTERVAL) end), 
    spawn(fun()-> do_campaign(?HEARTBEAT_INTERVAL) end),    
    io:format("Started Service  ~p~n",[{?MODULE}]),
    {ok, #state{dns_list=[],node_list=[],application_list=[],
		dns_info=DnsInfo,dns_addr={dns,DnsIp,DnsPort}}}.  
    
%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call({add,AppId,Vsn}, _From, State) ->
    io:format(" Add new application ~p~n",[{?MODULE,?LINE,time(),add,AppId,Vsn}]),
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    Reply=case lists:keyfind({AppId,Vsn},1,State#state.application_list) of
	      false->
		  case if_dns:call("catalog",latest,{catalog,read,[AppId,Vsn]},{DnsIp,DnsPort}) of
		      {error,Err}->
			  NewState=State,
			  io:format(" Error  ~p~n",[{?MODULE,?LINE,time(),Err}]),
			  {error,[?MODULE,?LINE,AppId,Vsn,Err]};
		      {ok,_,JoscaInfo}->
			  NewAppList=[{{AppId,Vsn},JoscaInfo}|State#state.application_list],
			  NewState=State#state{application_list=NewAppList},
			  ok;
		      Err ->
			  NewState=State,
			  io:format(" Error  ~p~n",[{?MODULE,?LINE,time(),Err}]),
			  {error,[?MODULE,?LINE,AppId,Vsn,Err]}
		  end;
	      _->
		  NewState=State,
		  io:format(" New application ~p~n",[{?MODULE,?LINE,time(),'already exists',AppId,Vsn}]),
		  {error,[?MODULE,?LINE,'already exists',AppId,Vsn]}
	  end,

    {reply, Reply,NewState};

handle_call({remove,AppId,Vsn}, _From, State)->
    Reply=case lists:keyfind({AppId,Vsn},1,State#state.application_list) of
	      false ->
		  NewState=State,
		  {error,[?MODULE,?LINE,'eexists',AppId,Vsn]};
	      {{AppId,Vsn},JoscaInfo}->
		  NewAppList=lists:keydelete({AppId,Vsn},1,State#state.application_list),
		  AllServices=rpc:call(node(),controller_lib,needed_services,[NewAppList,State]),
		  AppIdServices=rpc:call(node(),controller_lib,needed_services,[[{{AppId,Vsn},JoscaInfo}],State]),
		  ServicesToStop=[{X_ServiceId,X_Vsn}||{X_ServiceId,X_Vsn}<-AppIdServices,
						   false==lists:member({X_ServiceId,X_Vsn},AllServices)],
		  % DNS holds all information about services 
		  {dns,DnsIp,DnsPort}=State#state.dns_addr,
		  AvailableServices=if_dns:call("dns",latest,{dns,get_all_instances,[]},{DnsIp,DnsPort}),
		  NewDnsList=rpc:call(node(),controller_lib,stop_services,[ServicesToStop,AvailableServices,State]),
		  NewState=State#state{application_list=NewAppList,dns_list=NewDnsList},
		  ok
	  end,
    {reply, Reply,NewState};

handle_call({get_all_applications},_From, State) ->
    Reply=State#state.application_list,
    {reply, Reply, State};


handle_call({get_all_services},_From, State) ->
    Reply=State#state.dns_list,
    {reply, Reply, State};

handle_call({all_nodes},_From, State) ->
    Reply=State#state.node_list,
    {reply, Reply, State};


%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
handle_call({heart_beat},_,State) ->
    DnsInfo=State#state.dns_info,
    {dns,DnsIp,DnsPort}=State#state.dns_addr,
    if_dns:cast("dns",latest,{dns,dns_register,[DnsInfo]},{DnsIp,DnsPort}), 
    Now=erlang:now(),
    NewNodeList=[KubeletInfo||KubeletInfo<-State#state.node_list,
		      (timer:now_diff(Now,KubeletInfo#kubelet_info.time_stamp)/1000)<?INACITIVITY_TIMEOUT],

    NewState=State#state{node_list=NewNodeList},
    Reply=NewNodeList,
   {reply,Reply,NewState};


handle_call({campaign,Interval},_, State) ->
    Reply=rpc:call(node(),controller_lib,campaign,[State]),
    spawn(fun()-> do_campaign(Interval) end),
    {reply,Reply, State};

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

handle_call({stop}, _From, State) ->
    {stop, normal, shutdown_ok, State};

handle_call(Request, From, State) ->
    Reply = {unmatched_signal,?MODULE,Request,From},
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast({node_register,KubeletInfo}, State) ->
    NewState=controller_lib:node_register(KubeletInfo, State),
    {noreply, NewState};

handle_cast({de_node_register,KubeletInfo}, State) ->
     NewState=controller_lib:de_node_register(KubeletInfo, State),
    {noreply, NewState};

handle_cast(Msg, State) ->
    if_log:call(State#state.dns_info,error,[?MODULE,?LINE,'unmatched signal',Msg]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------


handle_info(Info, State) ->
    io:format("unmatched match info ~p~n",[{time(),?MODULE,?LINE,Info}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------


%% --------------------------------------------------------------------
%% Internal functions
%% --------------------------------------------------------------------
    

%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------
local_heart_beat(Interval)->
    ?MODULE:heart_beat(),
    timer:sleep(Interval),
    spawn(fun()-> local_heart_beat(Interval) end).


do_campaign(Interval)->
    timer:sleep(Interval),
    ?MODULE:campaign(Interval).
%% --------------------------------------------------------------------
%% Function: 
%% Description:
%% Returns: non
%% --------------------------------------------------------------------

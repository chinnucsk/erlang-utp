%% @doc Handle a queue of processes waiting on a socket
%%
%% This module abstracts a type of processes queues. When a process want to either send or
%% receive on a socket, it enqueues itself on these queues and waits in line. When we want
%% to feed data from the socket to rest of Erlang, we use processes from these queues to
%% do it.
%% @end
-module(utp_process).

-export([
	 mk/0,

	 enqueue_sender/3,
	 enqueue_receiver/3,

	 dequeue_packet/2
	]).
-record(process_info, {
	  receiver_q :: queue(),
	  sender_q   :: queue()
}).
-type t() :: #process_info{}.
-export_type([t/0]).

mk() ->
    #process_info { receiver_q = queue:new(),
		    sender_q   = queue:new() }.

enqueue_receiver(From, Length, #process_info { receiver_q = RQ } = PI) ->
    NQ = queue:in({receiver, From, Length, <<>>}, RQ),
    PI#process_info { receiver_q = NQ }.

enqueue_sender(From, Data, #process_info { sender_q = SQ } = PI) ->
    NQ = queue:in({sender, From, Data}, SQ),
    PI#process_info { sender_q = NQ }.

dequeue_packet(#process_info { sender_q = SQ } = PI, Size) when Size > 0 ->
    case queue:out(SQ) of
	{empty, _} ->
	    none;
	{value, {sender, From, Data}, Q} ->
	    case Data of
		<<Payload:Size/binary, Rest/binary>> ->
		    {value, Payload, PI #process_info {
				       sender_q = queue:in_r({sender, From, Rest}, Q)
				      }};
		<<Payload/binary>> ->
		    gen_utp:reply(From, ok),
		    {value, Payload, PI #process_info {
				       sender_q = Q }}
	    end
    end.

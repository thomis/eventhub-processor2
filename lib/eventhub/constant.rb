module EventHub
  EH_X_INBOUND             = 'event_hub.inbound'

  STATUS_INITIAL           = 0         # To be set when dispatcher needs to dispatch to first process step.

  STATUS_SUCCESS           = 200       # To be set to indicate successful processed message. Dispatcher will routes message to the next step.

  STATUS_RETRY             = 300       # To be set to trigger retry cycle controlled by the dispatcher
  STATUS_RETRY_PENDING     = 301       # Set and used by the dispatcher only.
                                       # Set before putting the message into a retry queue.
                                       # Once message has been retried it will sent do the same step with status.code = STATUS_SUCCESS

  STATUS_INVALID           = 400       # To be set to indicate invalid message (not json, invalid Event Hub Message).
                                       # Dispatcher will publish message to the invalid queue.

  STATUS_DEADLETTER        = 500       # To be set by dispatcher, processor or channel adapters to indicate
                                       # that message needs to be dead-lettered. Rejected messages could miss the
                                       # status.code = STATUS_DEADLETTER due to the RabbitMQ deadletter exchange mechanism.

  STATUS_SCHEDULE          = 600       # To be set to trigger scheduler based on schedule block, proceses next process step
  STATUS_SCHEDULE_RETRY    = 601       # To be set to trigger scheduler based on schedule block, retry actual process step
  STATUS_SCHEDULE_PENDING  = 602       # Set and used by the dispatcher only. Set before putting the scheduled message to the schedule queue.

  STATUS_CODE_TRANSLATION = {
    STATUS_INITIAL => 'STATUS_INITIAL',
    STATUS_SUCCESS => 'STATUS_SUCCESS',
    STATUS_RETRY => 'STATUS_RETRY',
    STATUS_RETRY_PENDING => 'STATUS_RETRY_PENDING',
    STATUS_INVALID => 'STATUS_INVALID',
    STATUS_DEADLETTER => 'STATUS_DEADLETTER',
    STATUS_SCHEDULE => 'STATUS_SCHEDULE',
    STATUS_SCHEDULE_RETRY => 'STATUS_SCHEDULE_RETRY',
    STATUS_SCHEDULE_PENDING =>'STATUS_SCHEDULE_PENDING',
  }
end

{application, kafka_demo,
  [{description, "Kafka consumer demo with full OTP stack"},
    {vsn, "0.2.0"},
    {modules, [kafka_demo_app, kafka_demo_sup, kafka_console_printer,
      kafka_gen_server, kafka_event_manager, kafka_stats_event]},
    {registered, [kafka_demo_sup, kafka_event_manager, kafka_gen_server]},
    {applications, [kernel, stdlib, brod]},
    {mod, {kafka_demo_app, []}},
    {env, [
      {kafka_hosts, [{"localhost", 9092}]},
      {client_id, my_kafka_client},
      {topic, <<"my-test-topic">>},
      {consumer_group, <<"kafka-demo-group">>},
      {compression, no_compression}
    ]}
  ]}.
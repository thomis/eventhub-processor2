## Soak / reliability harness

This folder contains a multi-process chaos test for the `eventhub-processor2`
gem. Four programs cooperate so that any reliability gap (lost messages,
zombie consumers, stuck publisher, ...) shows up as an orphan file in
`soak/data/`.

* `publisher.rb` - creates a unique file and a message, publishes to `example.outbound`
* `router.rb` - listens on `example.outbound`, re-publishes to `example.inbound`
* `receiver.rb` - listens on `example.inbound`, deletes the file with the given id
* `crasher.rb` - randomly restarts RabbitMQ or sends SIGHUP to router/receiver

```
publisher => [example.outbound] => router => [example.inbound] => receiver
```

### Goal

No matter what the crasher does, after a graceful shutdown and a drain
period `soak/data/` should contain only `store.json` (and that should
be `{}`).

### Quick start (via Makefile)

The project root has a `Makefile` that wraps everything:

```bash
make soak                              # 10-minute default soak, prints PASS/FAIL
SOAK_MINUTES=30 make soak              # longer
make soak-start                        # start all four manually
make soak-stop                         # SIGINT them all
make soak-clean                        # stop + wipe data/
make help                              # list targets and env knobs
```

The `soak` target runs the chaos loop, then `SIGKILL`s the publisher
(skipping its cleanup) so any in-flight file stays on disk as an honest
snapshot. After draining, it counts files in `data/` excluding `store.json`
and exits 0 if empty, 1 with the first 5 orphan ids if not.

### Manual start

Make sure the RabbitMQ container is running (see [docker readme](../docker/README.md)):

```bash
cd soak
bundle exec ruby receiver.rb   # in its own terminal
bundle exec ruby router.rb     # in its own terminal
bundle exec ruby publisher.rb  # in its own terminal
bundle exec ruby crasher.rb    # optional, in its own terminal
```

Graceful shutdown order: stop `publisher.rb` first, let `router`/`receiver`
drain the queues, then stop the rest. Check `soak/data/` afterwards.

### Publisher knobs (env overridable)

* `PAUSE_BETWEEN_WORK=F` - seconds between publishes (default `0.05` ~ 20 msg/s)
* `PUBLISH_MAX_ATTEMPTS=N` - publish retry attempts on transient Bunny errors (default `8`)
* `PUBLISH_RETRY_DELAY_S=F` - seconds between publish retries (default `1`)

The publisher uses `wait_for_confirms` (synchronous publisher confirms) and
retries `Bunny::NetworkFailure` / `Bunny::ChannelAlreadyClosed` / `Timeout::Error`
to bridge Bunny's channel-recovery window after a broker restart.

### Notes

* The publisher's `TransactionStore.cleanup` runs on graceful shutdown and
  deletes any pending file in `store.json`. That's why the `make soak`
  target uses `SIGKILL` for the publisher at the end - you want to see what
  was actually in flight at the moment the chaos phase ended.
* Watch for huge log files in `logs/ruby/` during long runs.

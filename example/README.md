## Example processor

`example.rb` is a minimal `EventHub::Processor2` subclass used to demo and
visually verify the gem's built-in HTTP endpoints (`/heartbeat`, `/version`,
`/docs`, `/changelog`, `/configuration`). It's intentionally tiny - just enough
to start a processor against the local RabbitMQ container.

For the chaos / reliability test harness (publisher, router, receiver,
crasher), see [`../soak/`](../soak/) and the `make soak` target in the
project root.

### Run

```bash
cd example
bundle exec ruby example.rb
```

Then visit `http://localhost:8083/svc/example/docs` (or whatever `http.port`
is configured in `config/example.json`).

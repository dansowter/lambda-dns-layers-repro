# Minimal reproduction of 2 potential issues.

You'll need to export a LOCALSTACK_API_KEY, then start localstack via docker-compose -

```bash
bin/start-localstack.sh
```

To reproduce a DNS-resolution issue, run -

```bash
bin/reproduce-issue-without-layers.sh
```

Note that the invoked lambda is started with the command-line option `--dns 127.0.0.1` and shows a corresponding warning.

To reproduce a separate issue related to lambda-layers (but which also likely has the same DNS problem), stop & restart the docker-compose script, then run -

```bash
bin/reproduce-issue-with-layers.sh
```

Note that the exported lambda function cannot be found.

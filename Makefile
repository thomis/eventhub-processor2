# Convenience targets for running and soak-testing the chaos harness in soak/.
# The gem itself is built via `rake` (see Rakefile).

SHELL          := /bin/bash
SOAK_DIR       := soak
DATA_DIR       := $(SOAK_DIR)/data
LOG_DIR        := $(SOAK_DIR)/logs
SOAK_MINUTES     ?= 10
SOAK_DRAIN_POLL_S ?= 5
SOAK_DRAIN_MAX_S  ?= 600

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make soak-start            start publisher, router, receiver, crasher in background"
	@echo "  make soak-stop             stop everything (SIGINT, clean shutdown)"
	@echo "  make soak-clean            stop and wipe $(DATA_DIR)/ + $(LOG_DIR)/"
	@echo "  make soak                  run reliability soak for SOAK_MINUTES (default 10) min"
	@echo ""
	@echo "Soak env overrides:"
	@echo "  SOAK_MINUTES=N             length of the chaos phase (default 10)"
	@echo "  SOAK_DRAIN_POLL_S=N        drain poll interval in seconds (default 5)"
	@echo "  SOAK_DRAIN_MAX_S=N         drain hard cap in seconds (default 600 = 10 min)"
	@echo ""
	@echo "Publisher env overrides (forwarded to publisher.rb):"
	@echo "  PAUSE_BETWEEN_WORK=F       seconds between publishes (default 0.05)"
	@echo "  PUBLISH_MAX_ATTEMPTS=N     publish retry attempts on transient errors (default 8)"
	@echo "  PUBLISH_RETRY_DELAY_S=F    seconds between publish retries (default 1)"

.PHONY: soak-start
soak-start: soak-stop
	@mkdir -p $(DATA_DIR)
	@echo "==> starting receiver"
	@cd $(SOAK_DIR) && nohup ruby receiver.rb  > /dev/null 2>&1 &
	@echo "==> starting router"
	@cd $(SOAK_DIR) && nohup ruby router.rb    > /dev/null 2>&1 &
	@sleep 3
	@echo "==> starting publisher"
	@cd $(SOAK_DIR) && nohup ruby publisher.rb > /dev/null 2>&1 &
	@sleep 2
	@echo "==> starting crasher"
	@cd $(SOAK_DIR) && nohup ruby crasher.rb   > /dev/null 2>&1 &
	@echo "==> all processes started; tail logs in $(SOAK_DIR)/logs/ruby/"

.PHONY: soak-stop
soak-stop:
	@pkill -INT -f "ruby (publisher|router|receiver|crasher)\.rb" 2>/dev/null || true
	@sleep 2

.PHONY: soak-clean
soak-clean: soak-stop
	@rm -rf $(DATA_DIR) $(LOG_DIR)
	@mkdir -p $(DATA_DIR) $(LOG_DIR)/ruby
	@echo "==> cleaned $(DATA_DIR) and $(LOG_DIR)"

# Soak: run the chaos loop for SOAK_MINUTES, then SIGKILL the publisher
# (skipping its cleanup so we keep an honest snapshot of any in-flight
# files), give router+receiver SOAK_DRAIN_S seconds to drain the queue,
# then count remaining files. Anything left is an orphan.
.PHONY: soak
soak:
	@started=$$(date +%s); started_human=$$(date '+%Y-%m-%d %H:%M:%S %Z'); \
	  chaos_ends_at=$$(date -r $$(($$started + $(SOAK_MINUTES) * 60)) '+%H:%M:%S' 2>/dev/null \
	                   || date -d @"$$(($$started + $(SOAK_MINUTES) * 60))" '+%H:%M:%S' 2>/dev/null); \
	  echo "==> soak: $(SOAK_MINUTES) min chaos + adaptive drain (cap $(SOAK_DRAIN_MAX_S)s)"; \
	  echo "    started:           $$started_human"; \
	  echo "    chaos ends ~       $$chaos_ends_at"; \
	  $(MAKE) --no-print-directory soak-clean; \
	  mkdir -p $(DATA_DIR); \
	  ( cd $(SOAK_DIR) && nohup ruby receiver.rb  > /dev/null 2>&1 & ); \
	  ( cd $(SOAK_DIR) && nohup ruby router.rb    > /dev/null 2>&1 & ); \
	  sleep 3; \
	  ( cd $(SOAK_DIR) && nohup ruby publisher.rb > /dev/null 2>&1 & ); \
	  sleep 2; \
	  ( cd $(SOAK_DIR) && nohup ruby crasher.rb   > /dev/null 2>&1 & ); \
	  echo "==> chaos phase running for $$(($(SOAK_MINUTES) * 60))s..."; \
	  sleep $$(($(SOAK_MINUTES) * 60)); \
	  echo "==> stopping crasher (SIGINT)"; \
	  pkill -INT -f "ruby crasher\.rb"   2>/dev/null || true; \
	  echo "==> SIGKILL publisher to skip its cleanup and freeze the snapshot"; \
	  pkill -KILL -f "ruby publisher\.rb" 2>/dev/null || true; \
	  sleep 1; \
	  drain_started=$$(date +%s); prev=-1; deadline=$$(($$drain_started + $(SOAK_DRAIN_MAX_S))); \
	  echo "==> draining (poll every $(SOAK_DRAIN_POLL_S)s, cap $(SOAK_DRAIN_MAX_S)s)"; \
	  echo "    (orphans = files with no matching store.json entry; in-flight = SIGKILL race, not a failure)"; \
	  while :; do \
	    now=$$(date +%s); \
	    read real in_flight <<< $$($(SOAK_DIR)/check_orphans.rb $(DATA_DIR)); \
	    elapsed_drain=$$(($$now - $$drain_started)); \
	    printf "    [%4ds] real=%d in_flight=%d\n" $$elapsed_drain $$real $$in_flight; \
	    if [ "$$real" = "0" ]; then break; fi; \
	    if [ $$now -ge $$deadline ]; then echo "    drain cap reached, giving up"; break; fi; \
	    if [ "$$real" = "$$prev" ]; then echo "    no progress in last interval, giving up"; break; fi; \
	    prev=$$real; \
	    sleep $(SOAK_DRAIN_POLL_S); \
	  done; \
	  finished=$$(date +%s); finished_human=$$(date '+%Y-%m-%d %H:%M:%S %Z'); \
	  elapsed=$$(($$finished - $$started)); \
	  read real in_flight <<< $$($(SOAK_DIR)/check_orphans.rb $(DATA_DIR)); \
	  echo ""; \
	  echo "==> soak result"; \
	  echo "    started:               $$started_human"; \
	  echo "    finished:              $$finished_human"; \
	  echo "    elapsed total:         $${elapsed}s"; \
	  echo "    drain time:            $$(($$finished - $$drain_started))s"; \
	  echo "    real orphans:          $$real  (pipeline loss)"; \
	  echo "    in-flight at SIGKILL:  $$in_flight  (expected residual; cleaned on next publisher start)"; \
	  $(MAKE) --no-print-directory soak-stop; \
	  if [ "$$real" = "0" ]; then \
	    echo "==> PASS"; \
	  else \
	    echo "==> FAIL: $$real real orphan(s) remain after drain"; \
	    $(SOAK_DIR)/check_orphans.rb $(DATA_DIR) --list-orphans >/dev/null; \
	    exit 1; \
	  fi

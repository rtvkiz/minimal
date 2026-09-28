---
title: "Kafka 4.x moved your config paths and didn't make a fuss about it"
description: "KRaft, Log4j 2, a renamed StorageTool class — Kafka 4.x changed four things upgraders hit blind, because the errors don't mention that a major version happened."
published: "2026-09-28"
---

Upgrading a Kafka image from 3.x to 4.x looks like a version bump. It isn't.
Four things moved, and each one fails with an error message that never
mentions "4.x" — you just get a stack trace or a missing file, and the fix
is to know what changed.

## 1. `kraft/` is gone from the config directory

Kafka has shipped both ZooKeeper-mode and KRaft-mode config templates side by
side for years, with KRaft's living under `config/kraft/server.properties`.
In 4.x, ZooKeeper support was removed entirely, and the KRaft config moved up
a level:

```
config/server.properties       # was config/kraft/server.properties in 3.x
```

If your entrypoint script or Dockerfile still references the old path, it
fails with a plain "no such file" — nothing in the error tells you the
directory structure changed upstream, because from the shell's point of view
a missing file is a missing file.

## 2. `StorageTool` moved packages

Before you can start a KRaft broker for the first time, you format its
storage directory:

```
java -cp '/opt/kafka/libs/*' kafka.tools.StorageTool random-uuid
java -cp '/opt/kafka/libs/*' kafka.tools.StorageTool format \
  -t "$CLUSTER_ID" -c /opt/kafka/config/server.properties
```

The class is `kafka.tools.StorageTool` — not `org.apache.kafka.tools.StorageTool`.
It's an easy guess to get wrong, because most of Kafka's public API lives
under `org.apache.kafka.*`, and this one doesn't. Get the package wrong and
you get `ClassNotFoundException`, which looks like a broken classpath, not a
wrong class name.

## 3. Log4j 1 → Log4j 2, and the flag changed with it

Kafka 4.0 migrated logging from Log4j 1 to Log4j 2. Three things changed
together:

| | Kafka 3.x | Kafka 4.x |
|---|---|---|
| Config file | `config/log4j.properties` | `config/log4j2.yaml` |
| Format | Java properties | YAML |
| JVM flag | `-Dlog4j.configuration=` | `-Dlog4j.configurationFile=` |

Passing the old flag name with the new config file doesn't error — Log4j 2
just falls back to its own default logging config and starts anyway, quietly
discarding whatever you thought you configured. No crash, no warning, just a
broker that logs at the wrong level or to the wrong place, which you notice
hours later when you go looking for a log line that was never written the
way you expected.

## 4. jlink needs `java.desktop` for a reason that has nothing to do with a GUI

If you're building a custom JRE with `jlink` to keep the image small, it's
tempting to drop every module that sounds unrelated to a headless broker —
and `java.desktop` sounds like exactly that: AWT, Swing, none of which Kafka
uses.

Drop it and Log4j 2 fails at startup with a `NoClassDefFoundError` reaching
for `java.beans.PropertyChangeEvent`. That class has lived in `java.beans`
since Java 9, and `java.beans` is part of the `java.desktop` module — not
because Kafka needs a desktop, but because `java.beans` was bundled with AWT
decades ago and nobody has split it out since. Log4j 2's `LoggerContext`
calls `updateLoggers()`, which fires a `PropertyChangeEvent`, which requires
the class to exist at all — whether or not anything is actually watching for
the change.

The fix is one line in the `jlink --add-modules` list:

```
--add-modules java.base,java.desktop,java.logging,java.management,...
```

It's a strange module to have to include in a "minimal" JRE for a headless
service, and that's exactly why it's worth writing down: the next person
trimming this list will look at `java.desktop` and assume it's dead weight.

## The pattern across all four

None of these four failures says "you're missing a Kafka 4.x migration
step." They say "file not found," "class not found," nothing at all, and
"class not found" again — because upstream's own release notes are the only
place that connects the dots, and nothing in the runtime error path quotes
them back to you. If you're scripting an upgrade across a major version,
read the release notes before the first failure, not after the fourth.

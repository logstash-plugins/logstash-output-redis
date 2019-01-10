## 5.0.0
  - Removed obsolete fields `queue` and `name`
  - Changed major version of redis library dependency to 4.x

## 4.0.4
  - Docs: Set the default_codec doc attribute.

## 4.0.3
  - Update gemspec summary

## 4.0.2
  - Tighten gem deps for the 'redis' gem
## 4.0.1
  - Fix some documentation issues

## 4.0.0
  - Mark deprecated `name` and `queue` configuration parameters as obsolete

## 3.0.3
  - Fix logging method signature for #debug
## 3.0.2
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99
## 3.0.1
  - Republish all the gems under jruby.
## 3.0.0
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141
# 2.0.5
  - Fix LocalJumpError exception see https://github.com/logstash-plugins/logstash-output-redis/pull/27
# 2.0.4
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.3
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0


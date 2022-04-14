---------- Server-wide settings ----------
-- Settings in this section apply to the whole server and are the default settings
-- for any virtual hosts

-- This is a (by default, empty) list of accounts that are admins
-- for the server. Note that you must create the accounts separately
-- (see https://prosody.im/doc/creating_accounts for info)
-- Example: admins = { "user1@example.com", "user2@example.net" }
admins = { }

-- Enable use of libevent for better performance under high load
-- For more information see: https://prosody.im/doc/libevent
use_libevent = true

-- This is the list of modules Prosody will load on startup.
-- It looks for mod_modulename.lua in the plugins folder, so make sure that exists too.
-- Documentation for bundled modules can be found at: https://prosody.im/doc/modules
{{- $modules_enabled := .Values.config.modules.enabled }}
{{- if .Values.service.bosh.enabled }}{{- $modules_enabled := append $modules_enabled "bosh" }}
consider_bosh_secure = true
{{- end }}
modules_enabled = {{ include "luaVal" $modules_enabled }}

-- These modules are auto-loaded, but should you want
-- to disable them then uncomment them here:
{{- $modules_disabled := .Values.config.modules.disabled }}
{{- if not .Values.service.xmpp.s2s.enabled }}
{{- $modules_disabled := append $modules_disabled "s2s" }}
{{- end }}
modules_disabled = {{ include "luaVal" $modules_disabled }}

-- Disable account creation by default, for security
-- For more information see https://prosody.im/doc/creating_accounts
allow_registration = {{ include "luaVal" .Values.config.allow_registration }}

-- Force clients to use encrypted connections? This option will
-- prevent clients from authenticating unless they are using encryption.

c2s_require_encryption = {{ include "luaVal" .Values.config.require_encryption.c2s }}

-- Force servers to use encrypted connections? This option will
-- prevent servers from authenticating unless they are using encryption.

s2s_require_encryption = {{ include "luaVal" .Values.config.require_encryption.s2s }}

-- Force certificate authentication for server-to-server connections?

s2s_secure_auth = {{ include "luaVal" .Values.config.s2s.secure_auth }}

-- Some servers have invalid or self-signed certificates. You can list
-- remote domains here that will not be required to authenticate using
-- certificates. They will be authenticated using DNS instead, even
-- when s2s_secure_auth is enabled.

s2s_insecure_domains = {{ include "luaVal" .Values.config.s2s.domains.insecure }}

-- Even if you disable s2s_secure_auth, you can still require valid
-- certificates for some domains by specifying a list here.

s2s_secure_domains = {{ include "luaVal" .Values.config.s2s.domains.secure }}

-- Select the storage backend to use. By default Prosody uses flat files
-- in its configured data directory, but it also supports more backends
-- through modules. An "sql" backend is included by default, but requires
-- additional dependencies. See https://prosody.im/doc/storage for more info.

storage = {{ include "luaVal" .Values.config.storage.backend }} -- Default is "internal"

{{- if eq .Values.config.storage.backend "sql" }}
sql = {{ include "luaVal" .Values.config.storage.sql }}
{{- end }}

-- You can also configure messages to be stored in-memory only. For more
-- archiving options, see https://prosody.im/doc/modules/mod_mam

-- Logging configuration
-- For advanced logging see https://prosody.im/doc/logging
log = {{ include "luaVal" (dict .Values.config.log_level "*console") }}

{{- if .Values.config.extra }}
{{ .Values.config.extra }}
{{- end }}

----------- Virtual hosts -----------
-- You need to add a VirtualHost entry for each domain you wish Prosody to serve.
-- Settings under each VirtualHost entry apply *only* to that host.

{{- range $vhost, $config := .Values.config.vhosts }}
VirtualHost {{ include "luaVal" $vhost }}
  {{- range $k, $v := $config }}
  {{ $k }} = {{ include "luaVal" $v | indent 2 | trim }}
  {{- end }}
{{- end }}

------ Components ------
-- You can specify components to add hosts that provide special services,
-- like multi-user conferences, and transports.
-- For more information on components, see https://prosody.im/doc/components

---Set up an external component (default component port is 5347)
--
-- External components allow adding various services, such as gateways/
-- transports to other networks like ICQ, MSN and Yahoo. For more info
-- see: https://prosody.im/doc/components#adding_an_external_component
--
--Component "gateway.example.com"
--	component_secret = "password"

{{- range $host, $config := .Values.config.components }}
Component {{ include "luaVal" $host }}{{- if (index $config "component") }} {{ include "luaVal" (index $config "component") }}{{- end }}
  {{- range $k, $v := (omit $config "component") }}
  {{ $k }} = {{ include "luaVal" $v | indent 2 | trim }}
  {{ end }}
{{- end }}

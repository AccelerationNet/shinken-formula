{% from 'shinken/macros.sls' import shinken_config, enable_module %}

{% set primary = salt['pillar.get']('shinken', default={
    'auth_secret': salt['key.finger'](),
    'scheduler_host': grains['fqdn'],
}, merge=True) %}

{% set graphite = salt['pillar.get']('shinken:graphite', default={
    'host': grains['fqdn'],
    'uri': 'http://' + grains['fqdn']
}, merge=True) %}



include:
  - shinken.config
  - shinken.poller-deps

primary-deps:
  pkg.installed:
    - pkgs:
      - memcached

# all daemons
shinken-primary:
  grains.present:
    - value: True
  service.running:
   - name: shinken
   - enable: True
   - reload: False
   - watch:
     - pip: shinken
     - file: /etc/shinken/*

# install/enable some modules
{% for mod in ['webui', 'auth-cfg-password', 'sqlitedb', 'graphite', 'ui-graphite', 'retention-memcache', 'nsca', 'ws-arbiter'] %}
{{enable_module(mod)}}
{% endfor %}

# configure the broker
{{shinken_config('brokers/broker-master.cfg', 'modules', 'webui,graphite')}}
{{shinken_config('modules/graphite.cfg', 'host', graphite.host)}}


# configure the web ui
{{shinken_config('modules/webui.cfg', 'auth_secret', primary.auth_secret)}}
{{shinken_config('modules/webui.cfg', 'modules', 'auth-cfg-password,ui-graphite,SQLitedb')}}
{{shinken_config('modules/ui-graphite.cfg', 'uri', graphite.uri)}}

# configure the scheduler
{{shinken_config('schedulers/scheduler-master.cfg', 'modules', 'MemcacheRetention')}}
{{shinken_config('schedulers/scheduler-master.cfg', 'address', primary.scheduler_host)}}

# configure the receiver
{{shinken_config('receivers/receiver-master.cfg', 'modules', 'nsca,ws-arbiter')}}

# get the shared shinken config
/etc/shinken/shinken.cfg:
  file.append:
    - text: "cfg_dir=/opt/shinken-config"


# write out config for workers

{% set workers = salt['pillar.get']('shinken:workers', {}) %}

{% for host, conf in workers.items() %}

/etc/shinken/pollers/{{host}}.cfg:
  file.managed:
    - source: salt://shinken/files/poller.cfg
    - template: jinja
    - mode: 444
    - defaults:
        host: {{host}}
        tags: ''
        realm: ''
    - context:
{% for key, value in conf.iteritems() %}
        {{ key }}: {{ value }}
{% endfor %}

{% endfor %}

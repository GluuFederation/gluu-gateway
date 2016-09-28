## Development
  
Unofficial document how to pick up local development environment for kong plugin. 

Prerequisite: install kong, cassandra.2.2.7, Intellij IDEA (with lua plugin)

1. start cassandra in foreground:
```
sudo sh /opt/cassandra_2.2.7/bin/cassandra -f
```

2. start kong with dev configuration
 ```
sudo su
cd /home/yuriy/IdeaProjects/kong
make dev
kong start -c /home/yuriy/IdeaProjects/kong/kong_DEVELOPMENT_.yml
kong stop -c /home/yuriy/IdeaProjects/kong/kong_DEVELOPMENT_.yml
kong reload -c /home/yuriy/IdeaProjects/kong/kong_DEVELOPMENT_.yml
```

3. link your kong plugin sources into kong internal plugins folder for convenient development
```
ln -s /home/yuriy/IdeaProjects/kong-plugins/kong-uma-rs/kong/plugins/kong-uma-rs /home/yuriy/IdeaProjects/kong/kong/plugins/
ln -s /home/yuriy/IdeaProjects/kong-plugins/kong-uma-rs/spec/plugins/kong-uma-rs /home/yuriy/IdeaProjects/kong/spec/plugins/
```

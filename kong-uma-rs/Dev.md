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

4. start oxd
sudo sh /home/yuriy/Downloads/oxd-server-2.4.4-distribution/bin/oxd-start.sh

5. cqlsh
```
export CQLSH_NO_BUNDLED=TRUE
cd /opt/cassandra_2.2.7/bin
sh cqlsh localhost
cqlsh> select * from kong_development.apis;
```

====================
1. Call customer api

curl -i -X GET --url http://localhost:8000/status/200/hello --header 'Host: mockbin.org'
  
2. Kong - Plugins

curl -i -X DELETE --url http://localhost:8001/apis/b1fdd250-6152-4f7d-880e-7a09255e9b7b/plugins/7208841a-dd4b-4101-89a1-bb5e6e5a3b0f
curl -i -X GET --url http://127.0.0.1:8001/apis
curl -i -X GET --url http://127.0.0.1:8001/apis/b1fdd250-6152-4f7d-880e-7a09255e9b7b/plugins
                                     
curl -i -X POST \
  --url http://localhost:8001/apis/b1fdd250-6152-4f7d-880e-7a09255e9b7b/plugins/ \
  --data 'name=kong-uma-rs' \
  --data "config.oxd_host=localhost" \
  --data "config.oxd_port=8099" \
  --data "config.uma_server_host=https://ce-dev2.gluu.org" \
  --data "config.protection_document={\"resources\":[{\"path\":\"/status/200/hello\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scopes\":[\"http://photoz.example.com/dev/actions/view\"]}]}]}"

curl -i -X GET --url http://localhost:8000/status/200/hello?bla=bla \
  --header 'Host: mockbin.org' \
  --header 'Authorization: Bearer gat_9b26e203-1b21-4298-a13b-9cc8b7b6cb9e/F4D8.22EB.B3B7.A39D.89BC.C26D.3A90.C735'
 
http://mockbin.org/status/200/hello?bla=bla



























  
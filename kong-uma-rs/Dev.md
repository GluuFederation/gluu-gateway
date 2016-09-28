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


==================================================================
1. Call customer api

curl -i -X GET --url http://localhost:8000/status/200/hello --header 'Host: mockbin.org'
  
2. Kong - Plugins

curl -i -X DELETE --url http://localhost:8001/apis/b1fdd250-6152-4f7d-880e-7a09255e9b7b/plugins/6e6814c2-af83-4e79-9fb4-8d8ad42a35f9  
curl -i -X GET --url http://127.0.0.1:8001/apis
curl -i -X GET --url http://127.0.0.1:8001/apis/b1fdd250-6152-4f7d-880e-7a09255e9b7b/plugins

curl -i -X POST \
  --url http://localhost:8001/apis/b1fdd250-6152-4f7d-880e-7a09255e9b7b/plugins/ \
  --data 'name=kong-uma-rs' \
  --data "config.oxd_host=localhost" \
  --data "config.oxd_port=8099" \
  --data "config.uma_server_host=https://ce-dev2.gluu.org" \
  --data "config.protection_document={\"resources\":[
                                         {
                                             \"path\":\"/status\",
                                             \"conditions\":[
                                                 {
                                                     \"httpMethods\":[\"GET\"],
                                                     \"scopes\":[
                                                         \"http://photoz.example.com/dev/actions/view\"
                                                     ]
                                                 }
                                             ]
                                         }
                                     ]
                                     }\"
 



























  
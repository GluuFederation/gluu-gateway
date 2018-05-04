<?xml version="1.0" encoding="UTF-8"?>
<WebElementEntity>
   <description></description>
   <name>div_Create API</name>
   <tag></tag>
   <elementGuidId>d0de26ce-70aa-4845-8248-c59677a5c20d</elementGuidId>
   <selectorMethod>BASIC</selectorMethod>
   <useRalativeImagePath>false</useRalativeImagePath>
   <webElementProperties>
      <isSelected>true</isSelected>
      <matchCondition>equals</matchCondition>
      <name>tag</name>
      <type>Main</type>
      <value>div</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>uib-modal-window</name>
      <type>Main</type>
      <value>modal-window</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>class</name>
      <type>Main</type>
      <value>modal fade ng-scope ng-isolate-scope in</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>role</name>
      <type>Main</type>
      <value>dialog</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>aria-labelledby</name>
      <type>Main</type>
      <value>modal-title</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>aria-describedby</name>
      <type>Main</type>
      <value>modal-body</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>size</name>
      <type>Main</type>
      <value>lg</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>index</name>
      <type>Main</type>
      <value>0</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>animate</name>
      <type>Main</type>
      <value>animate</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>ng-style</name>
      <type>Main</type>
      <value>{'z-index': 1050 + $$topModalIndex*10, display: 'block'}</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>tabindex</name>
      <type>Main</type>
      <value>-1</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>uib-modal-animation-class</name>
      <type>Main</type>
      <value>fade</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>modal-in-class</name>
      <type>Main</type>
      <value>in</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>modal-animation</name>
      <type>Main</type>
      <value>true</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>true</isSelected>
      <matchCondition>equals</matchCondition>
      <name>text</name>
      <type>Main</type>
      <value>
    
        Create API
        
            
        

    



    
        
    Name optional
    
        
        
        The API name. If none is specified, will default to the request_host or request_path.
    


    Hosts semi-optional
    
        
        
        A comma-separated list of domain names that point to your API. For example: example.com. At least one of hosts, uris, or methods should be specified.
    


    Uris semi-optional
    
        
        
        A comma-separated list of URIs prefixes that point to your API. For example: /my-path. At least one of hosts, uris, or methods should be specified.
    


    Methods semi-optional
    
        
        
        A comma-separated list of HTTP methods that point to your API. For example: GET,POST. At least one of hosts, uris, or methods should be specified.
    


    Upstream URL
    
        
        
        
            The base target URL that points to your API server, this URL will be used for proxying requests. For example, https://mockbin.com.
        
    


    Strip uri
        optional
    
        YES NO
        
            When matching an API via one of the uris prefixes, strip that matching prefix from the upstream URI to be requested. Default: true.
        
    


    Preserve Host
        optional
    
        YES NO
        
            When matching an API via one of the hosts domain names, make sure the request Host header is forwarded to the upstream service. By default, this is false, and the upstream Host header will be extracted from the configured upstream_url.
        
    


    Retries optional
    
        
        
        The number of retries to execute upon failure to proxy. The default is 5.
    


    Upstream connect timeout optional
    
        
        
        The timeout in milliseconds for establishing a connection to your upstream service. Defaults to 60000
    


    Upstream send timeout optional
    
        
        
        The timeout in milliseconds between two successive write operations for transmitting a request to your upstream service. Defaults to 60000
    


    Upstream read timeout optional
    
        
        
        The timeout in milliseconds between two successive read operations for transmitting a request to your upstream service. Defaults to 60000
    


    Https only
        optional
    
        YES NO
        
            To be enabled if you wish to only serve an API through HTTPS, on the appropriate port (8443 by default). Default: false.
        
    


    Http if terminated
        optional
    
        YES NO
        
            Consider the X-Forwarded-Proto header when enforcing HTTPS only traffic. Default: true.
        
    

        
            
                
                    
                    Submit API
                
            
        

    

</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>xpath</name>
      <type>Main</type>
      <value>id(&quot;konga&quot;)/body[@class=&quot;body ng-scope _expose-aside modal-open&quot;]/div[@class=&quot;modal fade ng-scope ng-isolate-scope in&quot;]</value>
   </webElementProperties>
</WebElementEntity>

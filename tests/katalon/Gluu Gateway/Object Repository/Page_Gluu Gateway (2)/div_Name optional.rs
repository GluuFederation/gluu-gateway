<?xml version="1.0" encoding="UTF-8"?>
<WebElementEntity>
   <description></description>
   <name>div_Name optional</name>
   <tag></tag>
   <elementGuidId>ead5f904-c64f-4a43-a086-95086076fc4c</elementGuidId>
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
      <name>data-ng-include</name>
      <type>Main</type>
      <value>partial</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>class</name>
      <type>Main</type>
      <value>ng-scope</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>true</isSelected>
      <matchCondition>equals</matchCondition>
      <name>text</name>
      <type>Main</type>
      <value>
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
        
    
</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>xpath</name>
      <type>Main</type>
      <value>id(&quot;modal-body&quot;)/form[@class=&quot;form-horizontal ng-valid ng-valid-url ng-dirty ng-valid-parse&quot;]/div[@class=&quot;ng-scope&quot;]</value>
   </webElementProperties>
</WebElementEntity>

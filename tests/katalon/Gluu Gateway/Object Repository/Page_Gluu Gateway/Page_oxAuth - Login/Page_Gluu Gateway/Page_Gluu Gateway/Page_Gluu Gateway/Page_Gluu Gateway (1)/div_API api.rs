<?xml version="1.0" encoding="UTF-8"?>
<WebElementEntity>
   <description></description>
   <name>div_API api</name>
   <tag></tag>
   <elementGuidId>ca35bb73-d8a8-4cf1-8369-e72f80548915</elementGuidId>
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
      <name>class</name>
      <type>Main</type>
      <value>main-container-wrapper-static</value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>true</isSelected>
      <matchCondition>equals</matchCondition>
      <name>text</name>
      <type>Main</type>
      <value>
    

      
        
          
            
            API api 
            
          
          
          
  apis apis
  edit API
  

        
        
        
    
        
            
                
                    
                    API Details
                
            
                
                    
                    Plugins
                
            
        
    
    
        
    
        
        
    



    
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
        
    

    
        
            
                
                Submit changes
            
        
    


        
  
    
      
      Assigned plugins
    
  
  
    
      
      add plugin
    
  



  
    
      
    
    
  
  


  
    
    
    Name
    Created
    
  
  
    
      
      
      
      
      

      ON OFF
    
    
      
    
    
      
      
        gluu-oauth2-client-auth
      
    
    Apr 22, 2018
    
      
        
        delete
      
    
  
  

        
    
        
            
            Health Checks

        
    
    
        ENABLED DISABLED

    




  
    
  CONFIGURATION

    
  STATUS



  
    
    
        
        
            
                Administrators can also be notified via email
                when an API is down or unresponsive
                by enabling Email Notifications in settings.
            
            
            
                HC Endpoint *
                
                Konga will perform a GET request to the specified endpoint every minute.
            
            
                Notification Endpoint (optional)
                
                Konga will perform a POST request to the specified endpoint the first time a health check fails and one every 15 minutes the API stays down or unresponsive.
            
            
            
                
                    save changes
                
            

        

    
    
        
        
            No info available yet...
            
                You need to enable health checks for this API
                in order to start getting HC status information.
            
            
        
        
            
                
                    Last known status
                    
                        
                        
                            
                            Down or unresponsive
                        
                    
                
                
                    Last checked
                    a few seconds ago
                
                
                    Last failed
                    Never
                
                
                    Last notified
                    Never
                
                
                    
                    
                        
                        Downtime
                    
                    
                    
                    
                        
                        a few seconds
                    
                    

                
            
        
    
  


    


      
    

  </value>
   </webElementProperties>
   <webElementProperties>
      <isSelected>false</isSelected>
      <matchCondition>equals</matchCondition>
      <name>xpath</name>
      <type>Main</type>
      <value>id(&quot;konga&quot;)/body[@class=&quot;body ng-scope _expose-aside&quot;]/div[@class=&quot;main-container-wrapper side-nav--animatable&quot;]/div[@class=&quot;main-container-wrapper-static&quot;]</value>
   </webElementProperties>
</WebElementEntity>

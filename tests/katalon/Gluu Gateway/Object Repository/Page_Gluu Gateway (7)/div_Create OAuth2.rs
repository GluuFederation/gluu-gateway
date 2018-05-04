<?xml version="1.0" encoding="UTF-8"?>
<WebElementEntity>
   <description></description>
   <name>div_Create OAuth2</name>
   <tag></tag>
   <elementGuidId>0fcb5bee-2a7c-444a-aa7f-988e7f5d49e3</elementGuidId>
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
  
    Create OAuth2
    
      
    
  


  Create OAuth2 for newC
  



  
    
      name 
        required
      
      
        
        
        A descriptive name used by the OAuth AS
      
    
    
      OAuth Mode
        optional
      
      
        YES NO
        
          If yes, the client must present an ACTIVE
          OAuth token to call an API.
        
      
    

    
      UMA Mode
        optional
      
      
        YES NO
        
          If yes, the client must present an ACTIVE UMA RPT token
          to call an  API.
        
      
    

    
      Mix Mode
        optional
      
      
        YES NO
        
          If yes, the client must present an ACTIVE
          OAuth token to call an API. Kong will
          obtain an UMA permission ticket, and attempt
          to obtain an RPT on behalf of the client.
          Client can send pushed claims using header3.5
          UMA_PUSHED_CLAIMS with JSON in980 6
          the following format:
          
            {&quot;claim_token&quot;:&quot;...&quot;,&quot;claim_token_format&quot;:&quot;...&quot;}
          
        
      
    

    
      Allow Unprotected path
        optional
      
      
        Allow Deny
        
          What to do when path is not protected by UMA-RS? If Deny then RS returns 401/Unauthorized.
        
      
    

    
      Restrict API's
        optional
      
      
        Enabled Disabled
        
          
          Select restricted API's
        
        
          The client can only call specified API's if client restriction is enabled.
        
      
    

    
      OAuth scope
        optional
      
      
        
          
          
        
        
          Security for OAuth scope.
        
      
    

    
      Show Consumer custom Id
        optional
      
      
        Yes No
        
          If Yes, then the plugin will set consumer custom id in legacy header otherwise not.
        
      
    

    
      
      
      
        
        
        
      
    

    
      OXD Id
        optional
      
      
        
        If you have existing oxd entry then enter oxd_id(also client id, client secret and client id of oxd id). If you
          have client created from OP server then skip it and enter only below client_id and client_secret. 
      
    

    
      Client Id
        optional
      
      
        
        If you have existing client then add value in Client Id and Client Secret.
      
    

    
      Client secret
        optional
      
      
        
        If you have existing client then add value in Client Id and Client Secret.
      
    

    
      Client Id of oxd id
        optional
      
      
        
        If you have existing oxd id then add value in Client Id of oxd id.
      
    

    
      JWKS URI
        optional
      
      
        
      
    

    
      JWKS File
        optional
      
      
        
      
    

    
      Token Auth Method
        optional
      
      
        - Please select one -client_secret_basicclient_secret_postclient_secret_jwtprivate_key_jwtaccess_tokennone
      
    

    
      Token Auth Alg
        optional
      
      
        - Please select one -HS256HS384HS512RS256RS384RS512ES256ES384ES512none
      
    

    
      
        
          
          Submit
        
      
    

  


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

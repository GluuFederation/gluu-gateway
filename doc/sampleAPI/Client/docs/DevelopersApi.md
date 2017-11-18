# swagger_client.DevelopersApi

All URIs are relative to *https://virtserver.swaggerhub.com/gluu/modena/1.0.0*

Method | HTTP request | Description
------------- | ------------- | -------------
[**search_inventory**](DevelopersApi.md#search_inventory) | **GET** /inventory | searches inventory


# **search_inventory**
> list[InventoryItem] search_inventory(search_string=search_string, skip=skip, limit=limit)

searches inventory

By passing in the appropriate options, you can search for available inventory in the system 

### Example 
```python
from __future__ import print_statement
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.DevelopersApi()
search_string = 'search_string_example' # str | pass an optional search string for looking up inventory (optional)
skip = 56 # int | number of records to skip for pagination (optional)
limit = 56 # int | maximum number of records to return (optional)

try: 
    # searches inventory
    api_response = api_instance.search_inventory(search_string=search_string, skip=skip, limit=limit)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling DevelopersApi->search_inventory: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **search_string** | **str**| pass an optional search string for looking up inventory | [optional] 
 **skip** | **int**| number of records to skip for pagination | [optional] 
 **limit** | **int**| maximum number of records to return | [optional] 

### Return type

[**list[InventoryItem]**](InventoryItem.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


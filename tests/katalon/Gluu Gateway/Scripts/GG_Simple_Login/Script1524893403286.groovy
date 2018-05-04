import static com.kms.katalon.core.testcase.TestCaseFactory.findTestCase
import static com.kms.katalon.core.testdata.TestDataFactory.findTestData
import static com.kms.katalon.core.testobject.ObjectRepository.findTestObject
import com.kms.katalon.core.checkpoint.Checkpoint as Checkpoint
import com.kms.katalon.core.checkpoint.CheckpointFactory as CheckpointFactory
import com.kms.katalon.core.mobile.keyword.MobileBuiltInKeywords as MobileBuiltInKeywords
import com.kms.katalon.core.mobile.keyword.MobileBuiltInKeywords as Mobile
import com.kms.katalon.core.model.FailureHandling as FailureHandling
import com.kms.katalon.core.testcase.TestCase as TestCase
import com.kms.katalon.core.testcase.TestCaseFactory as TestCaseFactory
import com.kms.katalon.core.testdata.TestData as TestData
import com.kms.katalon.core.testdata.TestDataFactory as TestDataFactory
import com.kms.katalon.core.testobject.ObjectRepository as ObjectRepository
import com.kms.katalon.core.testobject.TestObject as TestObject
import com.kms.katalon.core.webservice.keyword.WSBuiltInKeywords as WSBuiltInKeywords
import com.kms.katalon.core.webservice.keyword.WSBuiltInKeywords as WS
import com.kms.katalon.core.webui.keyword.WebUiBuiltInKeywords as WebUiBuiltInKeywords
import com.kms.katalon.core.webui.keyword.WebUiBuiltInKeywords as WebUI
import internal.GlobalVariable as GlobalVariable
import static com.kms.katalon.core.checkpoint.CheckpointFactory.findCheckpoint

def env = TestDataFactory.findTestData('Data Files/dev1TestData')

def host = env.getValue('Value', 1)

def username = env.getValue('Value', 2)

def password = env.getValue('Value', 3)

WebUI.openBrowser('')

WebUI.navigateToUrl(('https://' + host) + ':1338/#!/login')

WebUI.click(findTestObject('Page_Gluu Gateway/button_Login'))

WebUI.click(findTestObject('Page_oxAuth - Login/input_loginFormloginButton'))

WebUI.setText(findTestObject('Page_oxAuth - Login/input_loginFormusername'), username)

WebUI.setText(findTestObject('Page_oxAuth - Login/input_loginFormpassword'), password)

WebUI.click(findTestObject('Page_oxAuth - Login/input_loginFormloginButton'))

WebUI.waitForPageLoad(500)

if (WebUI.verifyElementPresent(findTestObject('Page_oxAuth/a_Allow'), 5, FailureHandling.OPTIONAL)) {
    WebUI.click(findTestObject('Page_oxAuth/a_Allow'))
}

WebUI.waitForElementPresent(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/a_'), 10)

WebUI.delay(10)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/a_'))

WebUI.waitForElementClickable(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/a_Logout'), 10)

WebUI.click(findTestObject('Page_Gluu Gateway/Page_oxAuth - Login/Page_Gluu Gateway/a_Logout'))

WebUI.closeBrowser()


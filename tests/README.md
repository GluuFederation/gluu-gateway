**Automated Gluu Gateway Tests for the 3 Modes**

Whenever in need of a quick sanity check for your server and Gluu services, use an automated tool which makes it easy and convenient. Our tests enable users to check the end-to-end flow of the customized plugins in the following three modes: OAUTH, UMA and Mix.
In order to use the test cases, download and install Mozilla Firefox and Katalon Studio, an open source solution for test automation. The download link is available on the official website: https://www.katalon.com/download. 

!!! Note Create a free account to download Katalon Studio.

The test repository is available at https://github.com/GluuFederation/gluu-gateway/tree/version_3.1.3/tests. Download its contents and copy to the Katalon folder. 
The next step is to run Katalon Studio and open the Gluu Gateway project. Do it by clicking File > Open Project in the menu and choosing the right path.

!(./tests/katalon_1.png)

Upon opening the project, you will see the four test cases in the tree to the left. Before running them, go to Data Files and change the variable values for your GG. Now, there are two ways to run the test cases: separately and together as a test suite. To run them separately, go back to Test Cases and open each one by clicking on them. Run a test by clicking the green Play button in the upper right menu. Following the same steps, run the whole Test Suite, GG_Tests, located just two clicks below the Test Cases.

!!! Note Always make sure Firefox is set as the default browser before running a test.

!(./tests/katalon_2.png)

Check the status of your test in the Log Viewer located below the test case window. A green bar means the test has passed, while a red one shows a failure. If there are any issues with the test case, view them in the Problems window or simply check the Console. 

!(./tests/katalon_3.png)

Happy testing!

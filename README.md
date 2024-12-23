## Building a REST API (CRUD) with Lambda,API GW and DynamoDB & REST API to SNS 

![alt text](./images/API_Overview.png)

## Implementation Guide
After successfully provisioned with terraform,

- API GW STAGE URL

    ![alt text](./images/API_GW_Stages.png)

1. Build a REST API(CRUD) with Lambda,API GW and DynamoDB

    ![alt text](./images/API_GW.png)

    - CREATE new data entries via API GW URL to DynamoDB Table

    ![alt text](./images/06.png)

    ![alt text](./images/07.png)

    - Two new data entries are successfully created in DynamoDB

    ![alt text](./images/08.png)

    - READ DynamoDB Table

    ![alt text](./images/09.png)

    ![alt text](./images/10.png)

    - UPDATE DynamoDB Table

        `{
        "employeeId" : "001",
        "updateKey" : "jobtitle",
        "updateValue"  : "Devops Engineer"
        }`

    ![alt text](./images/11.png)

    - DELETE DynamoDB Table Entry

    ![alt text](./images/13.png)

2. Check the entire DynamoDB Table

    `https://g5sc9h6hv6.execute-api.ap-southeast-1.amazonaws.com/dev/employees`

    ![alt text](./images/14.png)

3. Check the DynamoDB Table Health Status

    `https://g5sc9h6hv6.execute-api.ap-southeast-1.amazonaws.com/dev/status`

    ![alt text](./images/15.png)

4. Check the mock endpoint of API GW

    ![alt text](./images/16.png)

5. POST Method to SNS endpoint through API GW

    ![alt text](./images/17.png)

    - Sucessfully obtained POST request to receiver email address

        ![alt text](./images/18.png)
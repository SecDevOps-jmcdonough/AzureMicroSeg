# Azure K8S Micro Segmentation Workshop

## Workshop main objectives

* Deploy a Kubernetes Cluster
* Deploy FortiGate Infrastructure
* Deploy Azure Automation
* Micro Segmentation of Kubernetes Pods with FortiGate Automation Stitches

## Chapter 1 - Preparation Steps [estimated duration 5min]

An Azure Account with a valid Subscription is required.

1. Ensure you have the following tools available in your Azure Cloudshell:

    * [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) - `terraform --version`
    * [kubectl](https://kubernetes.io/docs/tasks/tools/) - `kubectl version`

    * Install the [aks-engine v0.65.0](https://github.com/Azure/aks-engine/releases/)
        * download aks-engine and transfer the binary to your home directory

    ```bash
        wget https://github.com/Azure/aks-engine/releases/download/v0.64.0/aks-engine-v0.64.0-linux-amd64.zip
        unzip aks-engine-v0.64.0-linux-amd64.zip
        mv aks-engine-v0.64.0-linux-amd64/aks-engine ./
        chmod +x aks-engine 
    ```

    * Clone the repository in your cloudshell

        `git clone https://github.com/fortinetsecdevops/AzureMicroSeg`

        ![clone](images/git_clone.jpg)

## Chapter 2 - Create the environment [estimated duration 20min]

1. Create the environment using the Terraform code provided.

    1. Update the `terraform.tfvars` file, provide values for these variables
        * azsubscriptionid = ""
        * project  = ""
        * TAG      = ""
        * username = ""
        * password = ""

        The `terraform.tfvars` file provides inputs for the resources that will be deployed.

    1. Run `terraform init`
        * Initialize the Terraform environment, download required providers

    1. Run `terraform validate`
        * Validate terraform files, references, variables, etc. If everything is valid, this message will be displayed
          `Success! The configuration is valid.`

    1. Run `terraform plan`
        * Plan what objects will be created, updated, destroyed

    1. Run `terraform apply`
        * Apply the terraform directives, terraform will ask for confirmation of the planned deployment, type `yes`

    At the end of this step you should have an environment similar to the below

    ![Globalenvironment](images/environment.jpg)

1. Deploy the Self-Managed cluster using aks-engine, a file customized to the deployment environment was created by the Terraform process.
    * Deployment File - `AzureMicroSeg/Terraform/aks-calico-azure.json`
    * These values were read from the deployment environment and used to create the file. The file is generated from code in the network.tf file
        * SUBSCRIPTION_ID
        * RESOURCE_GROUP_NAME
        * VNET_NAME
        * MASTER_SUBNET_NAME
        * MASTER_IP_ADDRESS - this value is set to the 10th IP in the subnet for Master Nodes
        * ADMIN_USER_NAME

    ```bash
    ./aks-engine deploy --dns-prefix k8smicroseg --resource-group RESOURCE_GROUP_NAME --location eastus --api-model ./AzureMicroSeg/Terraform/aks-calico-azure.json --auto-suffix
    ```

1. Verify that the deployment is successful by listing the K8S nodes. To access the cluster, transfer the kubeconfig file that was generated during the previous step, to the kubeconfig directory.

    ```bash
    mkdir ~/.kube

    cp  _output/k8smicroseg-RANDOM_ID/kubeconfig/kubeconfig.eastus.json ~/.kube/config

    kubectl get nodes -o wide
    ```

    ![clone](images/k8s-nodes.jpg)

    At the end of this step you should have the following setup

    ![Globalenvironment2](images/environment_chapter2.jpg)

1. Configure The [FortiGate K8S Connector](https://docs.fortinet.com/document/fortigate-private-cloud/7.0.0/kubernetes-administration-guide/718577) and verify that it's UP

    * Create a ServiceAccount for the FortiGate

        `kubectl create serviceaccount fgt-svcaccount`

    * Create a clusterrole

        `kubectl apply -f ./AzureMicroSeg/K8S/fgt-k8s-connector.yaml`

    * Create a clusterrolebinding

        `kubectl create clusterrolebinding fgt-connector --clusterrole=fgt-connector --serviceaccount=default:fgt-svcaccount`

    * Extract the ServiceAccount secret token and configure the FortiGate

        `kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='fgt-svcaccount')].data.token}"| base64 --decode`

    ![K8s-connector](images/k8s-connector.jpg)

1. Deploy two pods, one tagged with the label app=web and the other with the label app=db. You can use the provided example web-db-deployment.yaml

    `kubectl apply -f ./AzureMicroSeg/K8S/web-db-deployment.yaml`

    ![pods](images/k8s-pods.jpg)

**************

1. Questions

    * Why did the aks-engine deployment create Load balancers?
    * Why was a UDP/1123 load balancing rule created on the Master LB?
    * How many PODs can the deployed Node accommodate?
    * What are the changes required to make the communication to the MasterNode go through the FortiGate?

**************

## Chapter 3 - Create the RunBook and configure the FortiGate Automation Stitches [estimated duration 30min]

A FortiGate Automation Stitch brings together a trigger and an action. In this exercise the trigger is a log event and the action is the execution of a webhook.

* The trigger - a log event is generated when an IP address is added or removed from a dynamic address object
* The action - a webhook sends an HTTPS POST request to an endpoint in Azure. The endpoint runs a PowerShell script to update an Azure route table. The HTTP headers and JSON formatted body contain the information required to update the route table to manage micro-segmentation through the use of host routes. A host route is a route that indicates a specific host by using the IP-ADDRESS/32 in IPV4

This exercise covers the

* Setup of an Azure Automation Account
* Importing required Azure PowerShell Modules
* Creation and Publishing of Azure Runbook
* Creation of Webhook to invoke Azure Runbook
* Creation of FortiGate Dynamic Address
* Creation of FortiGate Automation Stitch
* Creation of FortiGate Automation Stitch Trigger
* Creation of FortiGate Automation Stitch Action

### Part 1. Azure

Automation in Azure can be accomplished in a number of ways, Logic Apps, Function Apps, Runbooks, etc. Each of the automation methods can be triggered in a number of ways, Events, Webhooks, Schedules, etc.

This part of the exercise goes through the process of creating an Azure Automation account that enables the running of an Azure Runbook via a Webhook. An Azure Runbook is just a PowerShell script that the Automation Account can run. The actions the Runbook can perform are controlled by the rights and scope (where those actions can be performed) that have been granted to the Automation Account.

The **Actions** are contained in the PowerShell Modules that have been imported into the Automation Account. The PowerShell Modules are libraries of commands called Cmdlets that are grouped into several domains. For example, Accounts, Automation, Compute, Network, and Resources.

All of the steps can be performed in the Azure Portal. However, the commands shown in each section can be run directly in Azure Cloudshell. Cloudshell has all the required utilities to execute the commands. Nothing additional needs to be loaded on a personal device.

> All of the PowerShell commands require the specification of a RESOURCE_GROUP_NAME
> To make it easy to copy and paste the commands sent an environment variable to the RESOURCE_GROUP_NAME of the FortiGate and K8s deployment
>
> For example, for a deployment Resource Group named 'k8s-microseg' create an environment variable like this.
>
> $env:RESOURCE_GROUP_NAME='k8s-microseg'
>

1. Azure Automation Account
    Create Automation Account [Automation Account](https://docs.microsoft.com/en-us/azure/automation/automation-create-standalone-account)

    1. Create a new Resource Group **OR** if using an existing Resource Group Skip this step.

    ```PowerShell
    New-AzResourceGroup -Name <RESOURCE_GROUP_NAME> -Location eastus
    ```

    1. Create an Automation Account in the Resource Group
        * Choose a Location
        * Provide a Name
        * Choose the Basic Plan
        * Indicate the assignment of a System Assigned Identity </br></br>

    ```PowerShell
    New-AzAutomationAccount -ResourceGroupName $env:RESOURCE_GROUP_NAME -Location eastus -Name user-automation-01 -AssignSystemIdentity -Plan Basic
    ```

    1. Setup Automation Account [Managed Identity] (<https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview>)

    ```PowerShell
    New-AzRoleAssignment -ObjectId (Get-AzAutomationAccount -ResourceGroupName $env:RESOURCE_GROUP_NAME -Name user-automation-01).Identity.PrincipalId -RoleDefinitionName "Contributor" -Scope (Get-AzResourceGroup -Name $env:RESOURCE_GROUP_NAME -Location eastus).ResourceId
    ```

    1. Import Az PowerShell Modules - These modules are not available by default in a Azure Automation Account. The Powershell command below can be used as an initial import to the Azure Automation Account or as an update.
        * Az.Accounts
        * Az.Automation
        * Az.Compute
        * Az.Network
        * Az.Resources

    ```PowerShell
    @("Accounts","Automation","Compute","Network","Resources") | ForEach-Object {Import-AzAutomationModule -ResourceGroupName $env:RESOURCE_GROUP_NAME -AutomationAccountName user-automation-01 -Name Az.$_  -ContentLinkUri https://www.powershellgallery.com/api/v2/package/Az.$_}
    ```

1. Azure Automation Runbook
    1. Create, Import, and Publish Runbook - A Runbook is simply the PowerShell Code that runs in response to a trigger. Triggers can be manual, scheduled, and webhook.

    ```PowerShell
    New-AzAutomationRunbook -ResourceGroupName $env:RESOURCE_GROUP_NAME -AutomationAccountName user-automation-01 -Name ManageDynamicAddressRoutes -Type PowerShell
    
    Import-AzAutomationRunbook -ResourceGroupName $env:RESOURCE_GROUP_NAME -Name ManageDynamicAddressRoutes -AutomationAccountName user-automation-01 -Path ./Azure/ManageDynamicAddressRoutes.ps1 -Type PowerShell –Force
    
    Publish-AzAutomationRunbook -ResourceGroupName $env:RESOURCE_GROUP_NAME -AutomationAccountName user-automation-01 -Name ManageDynamicAddressRoutes
    ```

    1. Create Webhook

    ```PowerShell
    New-AzAutomationWebhook -ResourceGroupName $env:RESOURCE_GROUP_NAME -AutomationAccountName user-automation-01 -RunbookName ManageDynamicAddressRoutes -Name routetableupdate -IsEnabled $True -ExpiryTime "11/30/2022" -Force
    ```

    The output will include the URL of the enabled webhook. The webhook is only viewable at creation and cannot be retrieved afterwards. The output will look similar to below.

    ```text
    ResourceGroupName     : automation-01
    AutomationAccountName : user-automation-01
    Name                  : routetableupdate
    CreationTime          : 7/13/2021 8:33:28 PM +00:00
    Description           :
    ExpiryTime            : 7/12/2022 12:00:00 AM +00:00
    IsEnabled             : True
    LastInvokedTime       : 1/1/0001 12:00:00 AM +00:00
    LastModifiedTime      : 7/13/2021 8:33:28 PM +00:00
    Parameters            : {}
    RunbookName           : ManageDynamicAddressRoutes
    WebhookURI            : https://f5f015ed-f566-483d-c972-0c2c3ca2a296.webhook.eus2.azure-automation.net/webhooks?token=P1GSd4Tasf5i1VYaVkFQvG29QCjkA8AOHY%2bsVLZOFSA%3d
    HybridWorker          :
    ```

1. FortiGate Dynamic Address
    * Create Dynamic Address to match a Web pod
        ![podsaddress](images/k8s-pods-address.jpg)

    * Repeat the same for the DB pod

1. FortiGate Automation Stitch
    * Create [Trigger](./FortiGate/routetableupdate-trigger.cfg)
        * Log Address Added
        * Log Address Removed
        ![FortiGate Automation Stitch Trigger](images/fgt-automation-stitch-trigger.jpg)
    * Create [Action](./FortiGate/routetableupdate-action.cfg)
        * Webhook
        * Body
        * Headers
        ![FortiGate Automation Stitch Action](images/fgt-automation-stitch-action.jpg)
    * Create [Stitch](./FortiGate/routetableupdate-stitch.cfg)
        * Trigger
        * Action
        ![FortiGate Automation Stitch Action](images/fgt-automation-stitch-stitch.jpg)

1. Delete the DB and Web pods to force their replacement. Check if the FGT detects an address change and triggers the automation Stich.
You can use the commands **diagnose debug  application autod -1** to debug the stich.

    ![podsaddressroute](images/k8s-pods-routeadded.jpg)

1. Access the web POD, install curl and try to connect to the DB Pod from the web POD. Example below (replace with your own POD name and ip address)

    ```bash
    kubectl get pods -o wide
    kubectl exec --tty --stdin web-deployment-66bf8c979c-ql2kn -- /bin/bash
    apt-get update
    apt-get install curl
    while true; do curl -v http://10.33.3.29:8080; sleep 2; done;
    ```

    ![podsaddresscurl](images/k8s-pods-curl.jpg)

**************

1. Questions

    * Is this setup secure? How is the runbook able to update the UDR without any authentication ?
    * There is no policy that allows traffic between Web-pod and DB-pod on the FGT. Why is it allowed?  

**************

## Chapter 4 - Scale the deployment and taint the nodes [estimated duration 10min]

1. Scale the K8S cluster to two nodes

    ```bash
    ./aks-engine scale --resource-group k8s-microseg --api-model /home/mounira/_output/k8smicroseg/apimodel.json  --new-node-count 2 --node-pool nodepool1 --apiserver  k8smicroseg.eastus.cloudapp.azure.com --location eastus
    ```

    [podsaddresscurl](images/scaledeployment.jpg)

1. Taint one node to receive Web pods only and the other one to receive DB pods (update with your own Node names)

    ```bash
    kubectl taint nodes k8s-nodepool1-20146942-0 app=web:NoSchedule
    kubectl taint nodes k8s-nodepool1-20146942-1 app=db:NoSchedule
    ```

1. Delete the previous deployments and create new ones with taint tolerations. You can use the provided example **web-db-deployment-tolerations.yaml**

    ```bash
    kubectl delete deployment db-deployment
    kubectl delete deployment web-deployment
    kubectl apply -f web-db-deployment-tolerations.yaml
    ```

    * Verify that the two pods are deployed in two different nodes. use the command **kubectl get pods -o wide**
    * Verify that the the route table has been updated accordingly

1. Access the web POD, install curl and try to connect to the DB Pod from the web POD.

**************

1. Questions

    * What is your conclusion ?

 **************

## Chapter 5 [Optional] - Calico policy to control traffic inside the cluster

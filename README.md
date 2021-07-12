# Azure K8S Micro Segmentation Workshop

## Workshop main objectives

## Chapter 1 - Preparation Steps

1. Ensure you have the following tools installed:

    * An Azure account with a valid subscription
    * Azure CLI,  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
    * Terraform, https://learn.hashicorp.com/tutorials/terraform/install-cli
    * kubectl,  https://kubernetes.io/docs/tasks/tools/
    * aks-engine v0.65.0, https://github.com/Azure/aks-engine/releases/ 


## Chapter 2 - Create the environment 

1. Create the environment
2. Deploy the Self-Managed cluster
3. Configure The FortiGate K8S Connector

    * Create a ServiceAccount for the FortiGate
    * Create a clusterrole
    * Create a clusterrolebinding
    * Extract the ServiceAccount secret token and configure the FortiGate

You can extract the secret token using the following command

```
kubectl get secret $(kubectl get serviceaccount fgt-svcaccount -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep token) -o go-template='{{.data.token | base64decode}}' && echo

``` 

4. Questions

## Chapter 3 - Create the RunBook and configure the ForiGate Automation Stiches

1. Create the runbook
2. Configure The FortiGate Automation Trigger 
3. Configure The FortiGate Automation Action
4. Questions
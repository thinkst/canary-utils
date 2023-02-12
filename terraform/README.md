## AWS EC2
**Prerequisites:** Requires the Canary AMI image shared with your AWS ID and preffered region. Contact support@canary.tools for assistance with this.
**Note** Values to be edited are marked with "<VALUE>".  
**Note** The AMI ID can be found in your [AMI catalogue](https://console.aws.amazon.com/ec2/v2/home#AMICatalog) and are region specific.

Terraform specific required launch permissions.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateNetworkInterface",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSubnet",
                "ec2:CreateVpc",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteSubnet",
                "ec2:DeleteVpc",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeCapacityReservations",
                "ec2:DescribeHosts",
                "ec2:DescribeImages",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeInstanceCreditSpecifications",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribePlacementGroups",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSpotPriceHistory",
                "ec2:DescribeSubnets"
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumesModifications",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcClassicLink",
                "ec2:DescribeVpcClassicLinkDnsSupport",
                "ec2:DescribeVpcs",
                "ec2:DetachNetworkInterface",
                "ec2:GetDefaultCreditSpecification",
                "ec2:GetEbsEncryptionByDefault",
                "ec2:RunInstances",
                "ec2:TerminateInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

If your environment enforces tags to be specified on EC2 instances you'll additionally need `ec2:CreateTags` and `ec2:DeleteTags`

## Azure
**Prerequisites:** An azure terraform deployment depends on the Canary app to have been deployed in your Azure environment, further documentation on this is available [here.] (https://help.canary.tools/hc/en-gb/articles/360012852217-How-do-I-create-an-Azure-Cloud-Canary-)
**Note** This terraform script will login to your Azure environment as the Canary app, this means the app will need permissiosn over the specific subscription ID to create resources. This can be done with the below snippet.

`$spObjId = az ad sp list --display-name '<YOUR CANARY APP NAME>' --query '[0].objectId' -o tsv | Out-String`
`az role assignment create --role Contributor --scope /subscriptions/<YOUR SUBSCRIPTION ID>  --assignee-principal-type ServicePrincipal --assignee-object-id $spObjId`

and later removed with:

`$spObjId = az ad sp list --display-name '<YOUR CANARY APP NAME>' --query '[0].objectId' -o tsv | Out-String`
`az role assignment delete --role Contributor --scope /subscriptions/<YOUR SUBSCRIPTION ID>  --assignee-principal-type ServicePrincipal --assignee-object-id $spObjId`

**Note** The Azure image gallary location can be found in the Canary deployment wizard as detailed in the guide [here.] (https://help.canary.tools/hc/en-gb/articles/360012852217-How-do-I-create-an-Azure-Cloud-Canary-)

## GCP
**Prerequisites:** Requires the Canary GCP image shared with your GCP service user, domain or group. Contact support@canary.tools for assistance with this.

## vSphere

### vSphere - Birds
**Prerequisites:** Requires the Canary vmware OVA to be available locally on the terraform host, this can be obtained from your console as detailed [here.](https://help.canary.tools/hc/en-gb/articles/360013050898-How-do-I-deploy-a-Virtual-Canary-on-VMware-vSphere-)

### vSphere - Tokens: SSH
**note** This terraform example creates a VMware virtual machine and then SSH's into it to deploy tokens, the created instance and SSH'd instance can be different.
**note** A script to run on the endpoint can be specified in the remote-exec provisioner, for example the [Python Multi-Dropper Script](https://github.com/thinkst/canary-utils/blob/master/python/CanaryToken_Multi-Dropper.py)

### vSphere - Tokens: WinRM
**note** This terraform example creates a VMware virtual machine and then deploys tokens with WinRM. The WinRM host can differ from the created instance.
**note** A script to run on the endpoint can be specified in the remote-exec provisioner, for example the [Powershell Multi-Dropper Script](https://github.com/thinkst/canary-utils/blob/master/powershell/CanaryToken_Multi-Dropper.ps1)

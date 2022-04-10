#!/bin/bash

# Set up ascii colors
ESC=$(printf '\033')
BOLD="${ESC}[1m"
REG="${ESC}[0m"
RED="${ESC}[31m"
BLUE="${ESC}[34m"
GREEN="${ESC}[32m"
NORMAL="${ESC}[39m"

teardown_instructions() {
  echo -e "

${BOLD}--------------------------------------------------------------------------

${BLUE}If there are no available VM sizes in the region you have selected, 
you will need to teardown your existing infrastructure and change your region.${NORMAL}${REG}

Run the following command and enter '${GREEN}yes${NORMAL}' when prompted.

${RED}/bin/bash ~/code/lab/scripts/remove_infrastructure.sh${NORMAL}


Once your infrastructure has been torn down, you will need to change to another
Azure region. Run the following command to remove the configuration file.

${RED}/usr/bin/sudo /bin/rm /var/sec510_regions.json${NORMAL}


After removing the configuration file, you can run the deployment script again.

"
  exit 1
}


# Check if Azure CLI is authenticated
if [[ $(az account list 2>/dev/null) == "[]" ]]; then
  printf "${RED}[!]${NORMAL} You need to run ${BLUE}az login${NORMAL} and following the prompts before running this script!\n"
  exit 1
fi

echo -e "
${BOLD}Checking Azure regions for available VM sizes${REG}
(Note: the check can take some time, please be patient.)"

REGIONS=( centralus northeurope eastasia )
for REGION in ${REGIONS[@]}; do
  echo; echo -e "${BOLD}${RED}--- ${BLUE}${REGION} ${RED}--------------------------${NORMAL}${REG}"

  az vm list-skus -l ${REGION} -r virtualMachines --all --query '[].{ Name: name, vCPUs: capabilities[2].value, Memory: capabilities[5].value, HyperVGenerations: capabilities[4].value, Restriction: restrictions[1].reasonCode } | sort_by(@,&Memory)' --output table | \
  awk 'NR<3 || ( \
       $1 !~ /_A/ && $1 !~ /_v5/ && $1 !~ /a_v4/ && 
       $2 < 4 && 
       $3 > 1 && $3 <= 8 && 
       $4 != "V2" ) {print}' | \
  egrep -v "(NotAvailableForSubscription|_Promo)" | \
  cut -c -40 

done

echo
trap 'teardown_instructions' SIGINT


echo -e "
Select one of the available VM sizes for your selected region below.
(Note: If no VM sizes are available in your region, please press <CTRL>-c )
"

read -p "VM name: " OVERRIDE

echo -e "\n\nCreating override file (${GREEN}~/code/lab/infrastructure/terraform/azure/override.tf${NORMAL})\n"
cat <<EOT | tee ~/code/lab/infrastructure/terraform/azure/override.tf
resource "azurerm_linux_virtual_machine" "sec510" {
  size = "${OVERRIDE}"
}
EOT

echo -e "${GREEN}Done!${NORMAL} Please re-run the deploy_infrastructure script.\n"


#!/bin/bash
set -ex

# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
# envman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'

# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.


main() {
	# download bitrise qr code image
	echo "Downloading" ${qr_code_image_url}
	curl --fail -Ss ${qr_code_image_url} --output ${confluence_attachment_name}
	if [[ $? -ne 0 ]]; then
		echo "Error while downloading ${qr_code_image_url} for contentId ${confluence_content_id}" >&2
		exit 1
	fi

	# upload qr code image
	echo "Uploading" "${confluence_attachment_name}"
	result=$(fetch "${confluence_attachment_name}")	
	if [ -z "$result" ]; then
		echo "No attachment found. Creating new"
		create "${confluence_attachment_name}"
	else
	 	update "${confluence_attachment_name}" "$result"
	fi
}

fetch () {
	info=$(curl --fail -Ss -u "${confluence_username}:${confluence_password}" -X GET "https://confluence.srg.beecollaboration.com/rest/api/content/${confluence_content_id}/child/attachment?filename=$1&expand=results")
	if [[ $? -ne 0 ]]; then
		echo "Error while retriving attachment ${confluence_attachment_name} for contentId ${confluence_content_id}" >&2
		exit 1
	fi   
	id=$(echo $info | jq -r --arg name "$1" '.results[] | select(.title==$name) | .id')
	if [[ $? -ne 0 ]]; then
		echo "Error while parsing json" >&2
		exit 2
	fi   	
	echo $id
} 

create () {
	curl --fail -Ss -u "${confluence_username}:${confluence_password}" -X POST -H "X-Atlassian-Token: no-check" -F "file=@$1" -F "comment=${confluence_comment}" "https://confluence.srg.beecollaboration.com/rest/api/content/${confluence_content_id}/child/attachment"
	if [[ $? -ne 0 ]]; then
		echo "Error while creating attachment $1 for contentId ${confluence_content_id}" >&2
		exit 1
	fi   
} 

update () {
	curl --fail -Ss -u "${confluence_username}:${confluence_password}" -X POST -H "X-Atlassian-Token: no-check" -F "file=@$1" -F "comment=${confluence_comment}" -F "minorEdit=false" "https://confluence.srg.beecollaboration.com/rest/api/content/${confluence_content_id}/child/attachment/$2/data"
	if [[ $? -ne 0 ]]; then
		echo "Error while updating attachment $1 with id $2 for contentId ${confluence_content_id} " >&2
		exit 1
	fi   	
}

main

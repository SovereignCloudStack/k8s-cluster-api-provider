#!/usr/bin/env bash
# Fill in OPENSTACK_CLOUD_YAML_B64, OPENSTACK_CLOUD_PROVIDER_CONF_B64,
#  OPENSTACK_CLOUD_CACERT_B64 into clusterctl.yaml

# yq installation done by bootstrap.sh
#sudo snap install yq

# Encode clouds.yaml
# Using application credentials, we don't need project_id, and openstackclient is
# even confused (asking for scoped tokens which fails). However, the cluster-api-provider-openstack
# does not consider the AuthInfo to be valid of there is no projectID. It knows how to derive it
# from the name, but not how to derive it from an application credential. (Not sure gophercloud
# even has the needed helpers.)
PROJECTID=$(grep 'tenant.id=' ~/cluster-defaults/cloud.conf | sed 's/^[^=]*=//')
CLOUD_YAML_ENC=$( (cat ~/.config/openstack/clouds.yaml; echo "      project_id: $PROJECTID") | base64 -w 0)
echo $CLOUD_YAML_ENC

# Encode cloud.conf
CLOUD_CONF_ENC=$(base64 -w 0 ~/cluster-defaults/cloud.conf)
echo $CLOUD_CONF_ENC

#Get CA and Encode CA
cloud_provider=$(yq eval '.CLOUD_PROVIDER' ~/cluster-defaults/clusterctl.yaml)
# Snaps are broken - can not access ~/.config/openstack/clouds.yaml
AUTH_URL=$(cat ~/.config/openstack/clouds.yaml | yq eval .clouds.${cloud_provider}.auth.auth_url -)
#AUTH_URL=$(grep -A12 "${cloud_provider}" ~/.config/openstack/clouds.yaml | grep auth_url | head -n1 | sed -e 's/^ *auth_url: //' -e 's/"//g')
AUTH_URL_SHORT=$(echo "$AUTH_URL" | sed s'/https:\/\///' | sed s'/\/.*$//')
CERT_CERT=$(openssl s_client -connect "$AUTH_URL_SHORT" </dev/null 2>&1 | head -n 1 | sed s'/.*CN\ =\ //' | sed s'/\ /_/g' | sed s'/$/.pem/')
CLOUD_CA_ENC=$(base64 -w 0 /etc/ssl/certs/"$CERT_CERT")
#CLOUD_CA_ENC="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tDQpNSUlGRmpDQ0F2NmdBd0lCQWdJUkFKRXJDRXJQREJpblUvYldMaVduWDFvd0RRWUpLb1pJaHZjTkFRRUxCUUF3DQpUekVMTUFrR0ExVUVCaE1DVlZNeEtUQW5CZ05WQkFvVElFbHVkR1Z5Ym1WMElGTmxZM1Z5YVhSNUlGSmxjMlZoDQpjbU5vSUVkeWIzVndNUlV3RXdZRFZRUURFd3hKVTFKSElGSnZiM1FnV0RFd0hoY05NakF3T1RBME1EQXdNREF3DQpXaGNOTWpVd09URTFNVFl3TURBd1dqQXlNUXN3Q1FZRFZRUUdFd0pWVXpFV01CUUdBMVVFQ2hNTlRHVjBKM01nDQpSVzVqY25sd2RERUxNQWtHQTFVRUF4TUNVak13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLDQpBb0lCQVFDN0FoVW96UGFnbE5NUEV1eU5WWkxEK0lMeG1hWjZRb2luWFNhcXRTdTV4VXl4cjQ1citYWElvOWNQDQpSNVFVVlRWWGpKNm9vamtaOVlJOFFxbE9idlU3d3k3YmpjQ3dYUE5aT09mdHoybndXZ3NidnNDVUpDV0gramR4DQpzeFBuSEt6aG0rL2I1RHRGVWtXV3FjRlR6alRJVXU2MXJ1MlAzbUJ3NHFWVXE3WnREcGVsUURScks5TzhadXRtDQpOSHo2YTR1UFZ5bVorREFYWGJweWIvdUJ4YTNTaGxnOUY4Zm5DYnZ4Sy9lRzNNSGFjVjNVUnVQTXJTWEJpTHhnDQpaM1Ztcy9FWTk2SmM1bFAvT29pMlI2WC9FeGpxbUFsM1A1MVQrYzhCNWZXbWNCY1VyMk9rLzVtems1M2NVNmNHDQova2lGSGFGcHJpVjF1eFBNVWdQMTdWR2hpOXNWQWdNQkFBR2pnZ0VJTUlJQkJEQU9CZ05WSFE4QkFmOEVCQU1DDQpBWVl3SFFZRFZSMGxCQll3RkFZSUt3WUJCUVVIQXdJR0NDc0dBUVVGQndNQk1CSUdBMVVkRXdFQi93UUlNQVlCDQpBZjhDQVFBd0hRWURWUjBPQkJZRUZCUXVzeGUzV0ZiTHJsQUpRT1lmcjUyTEZNTEdNQjhHQTFVZEl3UVlNQmFBDQpGSG0wV2VaN3R1WGtBWE9BQ0lqSUdsajI2WnR1TURJR0NDc0dBUVVGQndFQkJDWXdKREFpQmdnckJnRUZCUWN3DQpBb1lXYUhSMGNEb3ZMM2d4TG1rdWJHVnVZM0l1YjNKbkx6QW5CZ05WSFI4RUlEQWVNQnlnR3FBWWhoWm9kSFJ3DQpPaTh2ZURFdVl5NXNaVzVqY2k1dmNtY3ZNQ0lHQTFVZElBUWJNQmt3Q0FZR1o0RU1BUUlCTUEwR0N5c0dBUVFCDQpndDhUQVFFQk1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQ0FRQ0Z5azVIUHFQM2hVU0Z2TlZuZUxLWVk2MTFUUjZXDQpQVE5sY2xRdGdhRHF3KzM0SUw5ZnpMZHdBTGR1Ty9aZWxON2tJSittNzR1eUErZWl0Ulk4a2M2MDdUa0M1M3dsDQppa2ZtWlc0L1J2VFo4TTZVSys1VXpoSzhqQ2RMdU1HWUw2S3Z6WEdSU2dpM3lMZ2pld1F0Q1BrSVZ6NkQyUVF6DQpDa2NoZUFtQ0o4TXF5SnU1emx6eVpNakF2bm5BVDQ1dFJBeGVrcnN1OTRzUTRlZ2RSQ25iV1NEdFk3a2grQkltDQpsSk5Yb0IxbEJNRUtJcTRRRFVPWG9SZ2ZmdURnaGplMVdyRzlNTCtIYmlzcS95Rk9Hd1hEOVJpWDhGNnN3Nlc0DQphdkF1dkRzenVlNUwzc3o4NUsrRUM0WS93RlZETnZabzRUWVhhbzZaMGYrbFFLYzB0OERRWXprMU9YVnU4cnAyDQp5Sk1DNmFsTGJCZk9EQUxadllIN243ZG8xQVpsczRJOWQxUDRqbmtEclFveEIzVXFROWhWbDNMRUtRNzN4RjFPDQp5SzVHaEREWDhvVmZHS0Y1dStkZWNJc0g0WWFUdzdtUDNHRnhKU3F2MyswbFVGSm9pNUxjNWRhMTQ5cDkwSWRzDQpoQ0V4cm9MMSs3bXJ5SWtYUGVGTTVUZ085cjBydlphQkZPdlYyejBncDM1WjArTDRXUGxidUVqTi9seFBGaW4rDQpIbFVqcjhnUnNJM3FmSk9RRnkvOXJLSUpSMFkvOE9td3QvOG9UV2d5MW1kZUhtbWprN2oxbllzdkM5SlNRNlp2DQpNbGRsVFRLQjN6aFRoVjErWFdZcDZyamQ1SlcxemJWV0VrTE54RTdHSlRoRVVHM3N6Z0JWR1A3cFNXVFVUc3FYDQpuTFJid0hPb3E3aEh3Zz09DQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tDQo="

yq eval '.OPENSTACK_CLOUD_YAML_B64 = "'"$CLOUD_YAML_ENC"'"' -i ~/cluster-defaults/clusterctl.yaml
yq eval '.OPENSTACK_CLOUD_PROVIDER_CONF_B64 = "'"$CLOUD_CONF_ENC"'"' -i ~/cluster-defaults/clusterctl.yaml
yq eval '.OPENSTACK_CLOUD_CACERT_B64 = "'"$CLOUD_CA_ENC"'"' -i ~/cluster-defaults/clusterctl.yaml
# Generate SET_MTU_B64
#MTU=`yq eval '.MTU_VALUE' ~/cluster-defaults/clusterctl.yaml`
# Fix up nameserver list (trailing comma -- cosmetic)
sed '/OPENSTACK_DNS_NAMESERVERS:/s@, \]"@ ]"@' -i ~/cluster-defaults/clusterctl.yaml
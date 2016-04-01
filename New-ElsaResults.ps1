#
# ignore certificate errors
#
#
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#
#
# ignore certificate errors
#
#

#
#
# REPLACE
# REPLACE
# REPLACE
# set up the user and apikey from elsa
$user = "DougBurksIsMyHero"
$key = "beefbeefbeefbeefbeefvbeefbeef"
# REPLACE
# REPLACE
# REPLACE


function New-ElsaResults([string]$server, [string]$query, [int]$limit = 100, 
    [string]$cutoff = '',
    [int]$offset = 0,
    [string]$orderby = '',
    [string]$orderby_dir = 'asc',
    [string]$start = '1970-01-01 00:00:00',
    [string]$end = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"),
    [string]$groupby = '',
    [string]$node = '',
    [string]$datasource = '',
    [int]$timeout = 600,
    [int]$archive = 0,
    [int]$analytics = 0,
    [int]$nobatch = 0) {

    # build PSON object
    $q = [ordered]@{ "query_string" = $query;
        "query_meta_params" = [ordered]@{
            'limit' =  $limit;
            'cutoff' = $cutoff;
            'offset' = $offset;
            'orderby' = $orderby;
            'orderby_dir' = $orderby_dir;
            'start' = $start;
            'end' = $end;
            'groupby' = $groupby;
            'node' = $node;
            'datasource' = $datasource;
            'timeout' = $timeout;
            'archive' = $archive;
            'analytics' = $analytics;
            'nobatch' = $nobatch;
        }
    }

    New-ElsaResultsExec -server $server -query_param $q
}

# called by the parameterized version
function New-ElsaResultsExec([string]$server, $query_param) {
    # setup up the epoch info
    $1970 =  Get-Date -Date "1970-01-01 00:00:00Z"
    $now = Get-Date
    $epoch = [math]::floor((New-TimeSpan -Start $1970 -End $now).TotalSeconds)

    # string to make hash of
    $plaintext = "{0}{1}" -f $epoch, $key
    # setup up crypto
    $algo = [type]"System.Security.Cryptography.sha512"
    $crypto = $algo::Create()
    $plaintextBytes = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
    $hash = [System.BitConverter]::ToString($crypto.ComputeHash($plaintextBytes)).Replace("-", "").ToLower()
    # build the authentication header
    $headers = @{}
    $headers["Authorization"] = "ApiKey {0}:{1}:{2}" -f $user, $epoch, $hash
    # build the body
    $query_json = ConvertTo-Json $query_param -Compress
    $body = "permissions={0}&q={1}" -f [System.Web.HttpUtility]::UrlEncode('{"class_id":{"0":1},"program_id":{"0":1},"node_id":{"0":1},"host_id":{"0":1}}'),
        [System.Web.HttpUtility]::UrlEncode($query_json)

    #execute request
    Invoke-RestMethod -Method POST -Body $body -Headers $headers -Uri ("https://{0}/elsa-query/API/query" -f $server) -ContentType "application/x-www-form-urlencoded" -TimeoutSec 180
}
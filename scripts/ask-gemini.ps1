#!/usr/bin/env pwsh
# Script to prompt gemini 3.0 flash
# Before running make sure you set your $GEMINI_API_KEY env variable
# Made by @MihneaMoso

$ErrorActionPreference = "Stop"

$model_name = "gemini-2.5-flash" # default model
$endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{0}:generateContent" -f $model_name
$apiKey   = $env:GEMINI_API_KEY
# echo "$apikey"
echo "$endpoint"

$question = Read-Host "Ask"

$job = Start-Job -ScriptBlock {
    param($question, $endpoint, $apiKey)

    $body = @{
        contents = @(
            @{
                parts = @(
                    @{ text = $question }
                )
            }
        )
    } | ConvertTo-Json -Depth 10

    curl.exe -s `
        -X POST $endpoint `
        -H "Content-Type: application/json" `
        -H "x-goog-api-key: $apiKey" `
        -d $body
} -ArgumentList $question, $endpoint, $apiKey

# Spinner
$spinner = '|/-\'
$i = 0
while ($job.State -eq 'Running') {
    Write-Host "`rProcessing $($spinner[$i % $spinner.Length])" -NoNewline
    Start-Sleep -Milliseconds 120
    $i++
}
Write-Host "`rProcessing done.   "

$response = Receive-Job $job -Wait
Remove-Job $job

# Debug safety check
if (-not $response) {
    throw "Empty response from API"
}

# echo $response
$markdown = $response | jq -r '.candidates[0].content.parts[0].text'

if (-not $markdown) {
    throw "No markdown text found in response"
}

$markdown | glow -

# curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"   -H "x-goog-api-key: $GEMINI_API_KEY"   -H 'Content-Type: application/json'   -X POST   -d '{
#     "contents": [
#       {
#         "parts": [
#           {
#             "text": "How can I list the top 10 processes running on my linux system sorted by %cpu usage?"
#           }
#         ]
#       }
#     ]
#   }' | jq -r '.candidates[0].content.parts[0].text' | glow -

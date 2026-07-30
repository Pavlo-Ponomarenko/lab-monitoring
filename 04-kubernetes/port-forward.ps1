Start-Job -Name pf-grafana      -ScriptBlock { kubectl -n monitoring port-forward svc/grafana 3000:3000 }
Start-Job -Name pf-prometheus   -ScriptBlock { kubectl -n monitoring port-forward svc/prometheus 9090:9090 }
Start-Job -Name pf-alertmanager -ScriptBlock { kubectl -n monitoring port-forward svc/alertmanager 9093:9093 }
Start-Job -Name pf-web          -ScriptBlock { kubectl -n monitoring port-forward svc/web 8080:80 }

Get-Job   # check they're running
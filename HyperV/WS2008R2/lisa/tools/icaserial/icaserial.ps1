param (
        $VMHost = "localhost",
        $Timeout = 5,
        $Pipe,
        $Command
)

#
# This is a function to send request to a named pipe, which represents
# the serial port of specified VM. This function supports connecting to
# remote Hyper-V server by specifying $VMHost, if the remote Hyper-V
# server has remote management enabled.
#
function SendICARequest($VMHost, $Timeout, $Pipe, $Command)
{
    $session = New-PSSession -ComputerName $VMHost
    if ($session -eq $null) {
        Write-Warning "Please do 'winrm quickconfig' on $VMHost first."
        return $null
    }
    $response = Invoke-Command -Session $session -ScriptBlock {
        param ( $Timeout, $Pipe, $Command )
        $job = Start-Job -ScriptBlock {
            param ( $Pipe, $Command )

            Add-Type -AssemblyName System.Core
            $p = New-Object `
                    -TypeName System.IO.Pipes.NamedPipeClientStream `
                    -ArgumentList $Pipe
            $p.Connect()
            $writer = New-Object -TypeName System.IO.StreamWriter `
                                 -ArgumentList $p
            $reader = New-Object -TypeName System.IO.StreamReader `
                                 -ArgumentList $p
            $writer.AutoFlush = $true
            $writer.WriteLine($Command)
            $response = $reader.ReadLine()
            $writer.Close()
            $reader.Close()
            $p.Close()
            $response
        } -ArgumentList ($Pipe,$Command)
        Wait-Job -Job $job -Timeout $Timeout | Out-Null
        $response = Receive-Job -Job $job
        $response
    } -ArgumentList ($Timeout,$Pipe,$Command)
    Remove-PSSession -Session $session | Out-Null
    return $response
}
$response = SendICARequest $VMHost $Timeout $Pipe $Command
if ($response -eq $null -or $response -eq "")
{
    $WAIT_TIMEOUT = 258
    # Don't write output. It keeps the same behavior with icaserial.c
    # Write-Host "badCmd $WAIT_TIMEOUT"
    exit $WAIT_TIMEOUT
}
else
{
    Write-Host "$response"
    exit 0
}

$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$work = 'C:\Users\Anis\Desktop\Desktop\intertaxii\intertaxi'
$out = 'C:\Users\Anis\Desktop\Desktop\intertaxii\intertaxi\out_run.txt'
$err = 'C:\Users\Anis\Desktop\Desktop\intertaxii\intertaxi\out_run_err.txt'
$pidFile = 'C:\Users\Anis\Desktop\Desktop\intertaxii\intertaxi\out_run_pid.txt'

Remove-Item $out, $err -ErrorAction SilentlyContinue

$p = Start-Process -FilePath 'D:\flutter\bin\flutter.bat' `
    -ArgumentList 'run','-d','emulator-5554','--no-version-check' `
    -WorkingDirectory $work `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -WindowStyle Hidden `
    -PassThru

Set-Content -Path $pidFile -Value $p.Id -Encoding utf8
Write-Output ("Started PID " + $p.Id)
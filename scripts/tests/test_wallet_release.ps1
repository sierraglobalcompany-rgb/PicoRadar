$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../verify_wallet_release.ps1')

$header = @'
.class public Lcom/google/mlkit/common/internal/CommonComponentRegistrar;
.super Ljava/lang/Object;
.implements Lcom/google/firebase/components/ComponentRegistrar;
'@
$constructor = @'
.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method
'@
# Reduced from the failed release disassembly: references are not declarations.
$stripped = @'
.method public final a()Lsh1;
    .registers 15
    invoke-direct {v7}, Ljava/lang/Object;-><init>()V
    return-object v1
.end method
'@
$valid = "$header`n$constructor`n$stripped"
Assert-WalletRegistrarDex $valid
Assert-WalletRegistrarDex ($valid.Replace("`n", "`r`n"))

$cases = [ordered]@{
    'removed constructor, other constructor references survive' = "$header`n$stripped"
    'private constructor' = $valid.Replace('public constructor', 'private constructor')
    'argument constructor' = $valid.Replace('<init>()V', '<init>(I)V')
    'comment is not a declaration' = "$header`n# .method public constructor <init>()V`n$stripped"
    'wrong class' = $valid.Replace('CommonComponentRegistrar;', 'OtherRegistrar;')
    'missing interface' = $valid.Replace('.implements', '# .implements')
    'missing method body' = "$header`n.method public constructor <init>()V"
    'truncated constructor followed by another method' = "$header`n.method public constructor <init>()V`n$stripped"
    'abstract class' = $valid.Replace('.class public', '.class public abstract')
    'multiple classes' = "$valid`n$header"
    'empty tool output' = ''
}
foreach ($case in $cases.GetEnumerator()) {
    $rejected = $false
    try { Assert-WalletRegistrarDex $case.Value }
    catch {
        if ($_.Exception.Message -notlike 'Wallet release gate:*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "False positive: $($case.Key)" }
}
Write-Output "PASS: 2 valid DEX fixtures and $($cases.Count) invalid DEX fixtures."

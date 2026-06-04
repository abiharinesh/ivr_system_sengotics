$base = "c:/Users/DELL/Desktop/ivr_system_sengotics/ivr_frontend/lib"

# Fix all screen files that have ../../../../../core/models/ (5 up) -> ../../../../core/models/ (4 up)
$screenDirs = @(
    "$base/features/super_admin/presentation/screens",
    "$base/features/panchayat_admin/presentation/screens",
    "$base/features/electrician/presentation/screens",
    "$base/features/agent/presentation/screens"
)

foreach ($dir in $screenDirs) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -Filter '*.dart'
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            if ($content.Contains('../../../../../core/models/')) {
                $content = $content.Replace('../../../../../core/models/', '../../../../core/models/')
                Set-Content $f.FullName $content -NoNewline
                Write-Host "Fixed 5-up: $($f.Name)"
            }
        }
    }
}
Write-Host "Done fixing 5-up model paths"

# Now fix the screens that still reference ../../../config/ ../../../core/ etc
# These files moved from presentation/ to presentation/screens/
# so ../../../ anything (which was lib/anything) needs to become ../../../../anything
$allScreenDirs = @(
    "$base/features/super_admin/presentation/screens",
    "$base/features/panchayat_admin/presentation/screens",
    "$base/features/electrician/presentation/screens",
    "$base/features/agent/presentation/screens",
    "$base/features/customization/presentation/screens"
)

foreach ($dir in $allScreenDirs) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -Filter '*.dart'
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $changed = $false
            
            # Fix ../../../config/ -> ../../../../config/
            if ($content.Contains("'../../../config/")) {
                $content = $content.Replace("'../../../config/", "'../../../../config/")
                $changed = $true
            }
            
            # Fix ../../../core/ -> ../../../../core/
            if ($content.Contains("'../../../core/")) {
                $content = $content.Replace("'../../../core/", "'../../../../core/")
                $changed = $true
            }
            
            # Fix ../../../app.dart -> ../../../../app.dart
            if ($content.Contains("'../../../app.dart'")) {
                $content = $content.Replace("'../../../app.dart'", "'../../../../app.dart'")
                $changed = $true
            }
            
            # Fix relative bloc/data imports within same feature
            # From presentation/screens/X.dart to bloc/Y.dart was ../../bloc/ (from presentation/)
            # Now it needs to be ../../bloc/ still since screens/->presentation/->super_admin (has bloc/)
            # Actually: presentation/screens/ ->(../) presentation/ ->(../) super_admin/ -> bloc/
            # That's ../../bloc/ which is correct!
            # But if they had ../bloc/ before (from presentation/ to super_admin/bloc/), it needs ../../bloc/
            if ($content.Contains("'../bloc/")) {
                $content = $content.Replace("'../bloc/", "'../../bloc/")
                $changed = $true
            }
            
            # Fix ../data/ -> ../../data/ (same depth issue)
            if ($content.Contains("'../data/")) {
                $content = $content.Replace("'../data/", "'../../data/")
                $changed = $true
            }
            
            if ($changed) {
                Set-Content $f.FullName $content -NoNewline
                Write-Host "Fixed depth: $($f.Name)"
            }
        }
    }
}
Write-Host "Done fixing all screen depth issues"

# Fix complaint_model path for super_admin screens
# complaint_model is now at super_admin/data/models/
# From super_admin/presentation/screens/ -> ../../data/models/complaint_model.dart
$saScreenDir = "$base/features/super_admin/presentation/screens"
$files = Get-ChildItem -Path $saScreenDir -Filter '*.dart'
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    if ($content.Contains("../../../../core/models/complaint_model.dart")) {
        $content = $content.Replace("../../../../core/models/complaint_model.dart", "../../data/models/complaint_model.dart")
        Set-Content $f.FullName $content -NoNewline
        Write-Host "Fixed complaint_model path in: $($f.Name)"
    }
}

# Fix complaint_model for panchayat_admin screens
# From panchayat_admin/presentation/screens/ -> ../../../super_admin/data/models/complaint_model.dart
$paScreenDir = "$base/features/panchayat_admin/presentation/screens"
$files = Get-ChildItem -Path $paScreenDir -Filter '*.dart'
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    if ($content.Contains("../../../../core/models/complaint_model.dart")) {
        $content = $content.Replace("../../../../core/models/complaint_model.dart", "../../../super_admin/data/models/complaint_model.dart")
        Set-Content $f.FullName $content -NoNewline
        Write-Host "Fixed complaint_model path in PA: $($f.Name)"
    }
}

# Fix complaint_model for electrician screens
$elScreenDir = "$base/features/electrician/presentation/screens"
$files = Get-ChildItem -Path $elScreenDir -Filter '*.dart'
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    if ($content.Contains("../../../../core/models/complaint_model.dart")) {
        $content = $content.Replace("../../../../core/models/complaint_model.dart", "../../../super_admin/data/models/complaint_model.dart")
        Set-Content $f.FullName $content -NoNewline
        Write-Host "Fixed complaint_model path in EL: $($f.Name)"
    }
}

# Fix complaint_model for blocs that reference it 
# super_admin/bloc/complaint_bloc.dart
$saComplaintBloc = "$base/features/super_admin/bloc/complaint_bloc.dart"
$content = Get-Content $saComplaintBloc -Raw
if ($content.Contains("../../core/models/complaint_model.dart")) {
    $content = $content.Replace("../../core/models/complaint_model.dart", "../data/models/complaint_model.dart")
    Set-Content $saComplaintBloc $content -NoNewline
    Write-Host "Fixed complaint_model in SA complaint_bloc"
}

# panchayat_admin/bloc/pa_complaint_bloc.dart
$paComplaintBloc = "$base/features/panchayat_admin/bloc/pa_complaint_bloc.dart"
$content = Get-Content $paComplaintBloc -Raw
if ($content.Contains("../../core/models/complaint_model.dart")) {
    $content = $content.Replace("../../core/models/complaint_model.dart", "../../super_admin/data/models/complaint_model.dart")
    Set-Content $paComplaintBloc $content -NoNewline
    Write-Host "Fixed complaint_model in PA pa_complaint_bloc"
}

# Fix complaint_model in core widgets that reference it
$coreWidgetFiles = Get-ChildItem -Path "$base/core/widgets" -Filter '*.dart'
foreach ($f in $coreWidgetFiles) {
    $content = Get-Content $f.FullName -Raw
    if ($content.Contains("../models/complaint_model.dart")) {
        $content = $content.Replace("../models/complaint_model.dart", "../../features/super_admin/data/models/complaint_model.dart")
        Set-Content $f.FullName $content -NoNewline
        Write-Host "Fixed complaint_model in core widget: $($f.Name)"
    }
}

# Fix complaint_model in super_admin data/super_admin_repository.dart
$saRepo = "$base/features/super_admin/data/super_admin_repository.dart"
$content = Get-Content $saRepo -Raw
if ($content.Contains("../../core/models/complaint_model.dart")) {
    $content = $content.Replace("../../core/models/complaint_model.dart", "models/complaint_model.dart")
    Set-Content $saRepo $content -NoNewline
    Write-Host "Fixed complaint_model in super_admin_repository"
}

# Fix complaint_model in panchayat_admin data
$paRepo = "$base/features/panchayat_admin/data/panchayat_admin_repository.dart"
$content = Get-Content $paRepo -Raw
if ($content.Contains("../../core/models/complaint_model.dart")) {
    $content = $content.Replace("../../core/models/complaint_model.dart", "../../super_admin/data/models/complaint_model.dart")
    Set-Content $paRepo $content -NoNewline
    Write-Host "Fixed complaint_model in panchayat_admin_repository"
}

# Fix tender_models path in tender repository
$tenderRepo = "$base/features/tenders/data/tender_repository.dart"
$content = Get-Content $tenderRepo -Raw
if ($content.Contains("'tender_models.dart'")) {
    $content = $content.Replace("'tender_models.dart'", "'models/tender_models.dart'")
    Set-Content $tenderRepo $content -NoNewline
    Write-Host "Fixed tender_models in tender_repository"
}

# Fix tender_models in tender screens
$tenderScreenDir = "$base/features/tenders/presentation/screens"
$tenderScreenFiles = Get-ChildItem -Path $tenderScreenDir -Filter '*.dart'
foreach ($f in $tenderScreenFiles) {
    $content = Get-Content $f.FullName -Raw
    if ($content.Contains("../../data/tender_models.dart")) {
        $content = $content.Replace("../../data/tender_models.dart", "../../data/models/tender_models.dart")
        Set-Content $f.FullName $content -NoNewline
        Write-Host "Fixed tender_models in: $($f.Name)"
    }
}

# Fix tender_models in tender widgets
$tenderWidgetDir = "$base/features/tenders/presentation/widgets"
if (Test-Path $tenderWidgetDir) {
    $tenderWidgetFiles = Get-ChildItem -Path $tenderWidgetDir -Filter '*.dart'
    foreach ($f in $tenderWidgetFiles) {
        $content = Get-Content $f.FullName -Raw
        if ($content.Contains("../../data/tender_models.dart")) {
            $content = $content.Replace("../../data/tender_models.dart", "../../data/models/tender_models.dart")
            Set-Content $f.FullName $content -NoNewline
            Write-Host "Fixed tender_models in widget: $($f.Name)"
        }
    }
}

Write-Host "`nAll comprehensive import fixes complete!"

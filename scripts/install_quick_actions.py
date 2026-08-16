import os
import plistlib

services_dir = os.path.expanduser('~/Library/Services')
os.makedirs(services_dir, exist_ok=True)

def create_quick_action(name, action_cmd):
    wf_dir = os.path.join(services_dir, f'{name}.workflow', 'Contents')
    os.makedirs(wf_dir, exist_ok=True)
    
    info_plist = {
        'CFBundleDevelopmentRegion': 'en',
        'CFBundleIdentifier': f'com.zipmip.service.{name.lower().replace(" ", "_").replace("(", "").replace(")", "")}',
        'CFBundleInfoDictionaryVersion': '6.0',
        'CFBundleName': name,
        'CFBundlePackageType': 'BNDL',
        'CFBundleShortVersionString': '1.0',
        'CFBundleVersion': '1',
        'NSServices': [{
            'NSMenuItem': {'default': name},
            'NSMessage': 'runWorkflowAsService',
            'NSSendFileTypes': ['public.item'],
            'NSSendTypes': ['NSFilenamesPboardType'],
            'NSRequiredContext': {'NSTextContent': 'FilePath'}
        }]
    }
    with open(os.path.join(wf_dir, 'Info.plist'), 'wb') as f:
        plistlib.dump(info_plist, f)

    wflow_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>{action_cmd}</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
            </dict>
        </dict>
    </array>
    <key>workflowMetaData</key>
    <dict>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>'''
    with open(os.path.join(wf_dir, 'document.wflow'), 'w') as f:
        f.write(wflow_content)
    print(f'✅ Installed Quick Action: {name}')

if __name__ == '__main__':
    cmd_zip = 'python3 -c "import urllib.parse, sys, subprocess; query = \'&\'.join([\'path=\' + urllib.parse.quote(p) for p in sys.argv[1:]]); subprocess.run([\'open\', \'zipmip://compressToZip?\' + query])" "$@"'
    cmd_7z = 'python3 -c "import urllib.parse, sys, subprocess; query = \'&\'.join([\'path=\' + urllib.parse.quote(p) for p in sys.argv[1:]]); subprocess.run([\'open\', \'zipmip://compressTo7z?\' + query])" "$@"'
    cmd_extract = 'python3 -c "import urllib.parse, sys, subprocess; query = \'&\'.join([\'path=\' + urllib.parse.quote(p) for p in sys.argv[1:]]); subprocess.run([\'open\', \'zipmip://extractHere?\' + query])" "$@"'

    create_quick_action('Compress to ZIP (ZipMip)', cmd_zip)
    create_quick_action('Compress to 7Z (ZipMip)', cmd_7z)
    create_quick_action('Extract with ZipMip', cmd_extract)

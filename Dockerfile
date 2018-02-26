FROM python:2-windowsservercore-ltsc2016
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]


###vvvvvvvvvvvvvvvvvvvv###
## Manage some pre-requisites
RUN powershell Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
# Chocolatey
ENV ChocolateyUseWindowsCompression false
RUN iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco feature disable --name showDownloadProgress
##
RUN C:\ProgramData\chocolatey\bin\choco install git.install -y;
###^^^^^^^^^^^^^^^^^^^^###

###vvvvvvvvvvvvvvvvvvvv###
# Install .NET Fx 3.5 - a pre-req for vcpython27.
#  Taken from microsoft/dotnet-framework:3.5-windowsservercore-ltsc2016
RUN $ErrorActionPreference = 'Stop'; \
    $ProgressPreference = 'SilentlyContinue'; \
    Invoke-WebRequest \
      -UseBasicParsing \
      -Uri "https://dotnetbinaries.blob.core.windows.net/dockerassets/microsoft-windows-netfx3-ltsc2016.zip" \
      -OutFile microsoft-windows-netfx3.zip; \
    Expand-Archive microsoft-windows-netfx3.zip; \
    Remove-Item -Force microsoft-windows-netfx3.zip; \
    Add-WindowsPackage -Online -PackagePath .\microsoft-windows-netfx3\microsoft-windows-netfx3-ondemand-package.cab; \
    Remove-Item -Force -Recurse microsoft-windows-netfx3

# Apply latest patch
RUN $ErrorActionPreference = 'Stop'; \
    $ProgressPreference = 'SilentlyContinue'; \
    Invoke-WebRequest \
      -UseBasicParsing \
      -Uri "http://download.windowsupdate.com/c/msdownload/update/software/secu/2018/01/windows10.0-kb4056890-x64_1d0f5115833be3d736caeba63c97cfa42cae8c47.msu" \
      -OutFile patch.msu; \
    New-Item -Type Directory patch; \
    Start-Process expand -ArgumentList 'patch.msu', 'patch', '-F:*' -NoNewWindow -Wait; \
    Remove-Item -Force patch.msu; \
    Add-WindowsPackage -Online -PackagePath C:\patch\Windows10.0-KB4056890-x64.cab; \
    Remove-Item -Force -Recurse \patch

# ngen .NET Fx
RUN set COMPLUS_NGenProtectedProcess_FeatureEnabled=0; \
    \Windows\Microsoft.NET\Framework64\v4.0.30319\ngen update; \
    \Windows\Microsoft.NET\Framework\v4.0.30319\ngen update; \
    \Windows\Microsoft.NET\Framework64\v2.0.50727\ngen update; \
    \Windows\Microsoft.NET\Framework\v2.0.50727\ngen update
###^^^^^^^^^^^^^^^^^^^^###

###vvvvvvvvvvvvvvvvvvvv###
## Visual C++ Compiler for Python 2.7 - pre-req for brive.
RUN C:\ProgramData\chocolatey\bin\choco install vcpython27 -y; 
###^^^^^^^^^^^^^^^^^^^^###


###vvvvvvvvvvvvvvvvvvvv###
### Install GAM
#   We are using the source because the gam.exe had an issue with utf-8 (cp65001) support in powershell.
#
ENV GAM_VER=4.40
ENV PYTHONIOENCODING=utf-8
RUN Invoke-WebRequest -Uri "https://github.com/jay0lee/GAM/archive/v${env:GAM_VER}.zip" -OutFile C:\gam.zip; \
    Expand-Archive C:\gam.zip -DestinationPath C:\; Remove-Item -Force C:\gam.zip;
#   To work around issue https://github.com/MicrosoftDocs/Virtualization-Documentation/issues/497 
#   The C:\gam folder has to be empty when we mount it.  Therefore, the user must copy gam.py and other contents into this mount.
RUN New-Item -Type Directory -Path C:\gam-src; \
    Copy-Item -Recurse "C:\GAM-${env:GAM_VER}\src\*" C:\gam-src\; \
    New-Item -Type File C:\gam-src\nobrowser.txt; New-Item -Type File C:\gam-src\noupdatecheck.txt; New-Item -Type File C:\gam-src\nocache.txt;  \
    Remove-Item -Force -Recurse "C:\GAM-${env:GAM_VER}"; \
    pip install pyopenssl --upgrade;
###^^^^^^^^^^^^^^^^^^^^###

###vvvvvvvvvvvvvvvvvvvv###
### Install Brive
### We are installing from a specific commit - Just so we don't get a surprise update.
ENV BRIVE_COMMIT c29748ab23677089b1697e0d9e0d7cf45e90a294
ENV LC_ALL en_US.UTF-8
RUN pip install httplib2 --upgrade; \
    pip install streaming_httplib2 --upgrade; \
    pip install cryptography --upgrade; \
    git clone -b master https://github.com/BarnumD/Brive.git C:\brive; \
    cd c:\brive; git reset --hard $env:BRIVE_COMMIT; \
    (Get-Content c:\brive\setup.py).replace('Brive==0.3.11', 'Brive==0.4.0') | Set-Content c:\brive\setup.py; \
    python c:\brive\setup.py install -n

### Configure Our scripts 
COPY scripts /scripts

ENTRYPOINT ["powershell", "-NoProfile", "-Command"]
CMD ["C:\\scripts\\drive_backup.ps1"]

VOLUME C:\\data
VOLUME C:\\config
VOLUME C:\\gam
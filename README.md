One-command Tor setup with obfs4 bridges and SOCKS5 proxy

I tried hard to make it cross-platform, but tested on arch only (yet)

```bash
# Place bridges.age in current directory
./install.sh
```

This will ask password for encrypted file with bridges. I encrypt them because I do not support spreading bridges openly, since many providers (or whoever) block them the moment they are exposed. Those are obfs4, but I personally recommend using snowflake or webtunnel (will upgrade the utility later)

> Please, contact me for the password at vector-anonymous proton.me

Or crack it lol

### That's it

## Usage

* Telegram

The script generates link for TG; you can also manually configure it:

    Server: 127.0.0.1

    Port: 9150 

I have changed port to 9150 in case you already run tor from 9050 and forgot about it; but i've also provided tor masking so that similar processes do not conflict 

* Command Line

```
torsocks curl https://check.torproject.org/api/ip
```

* Browser

Configure SOCKS5 proxy to 127.0.0.1:9150

> Please, contact me for recommendations on how to set up your browser for better privacy

## Management

```
# Start/Stop (Linux)
sudo systemctl start tor-custom.service
sudo systemctl stop tor-custom.service

# View logs
sudo journalctl -u tor-custom.service -f

# Manual run (macOS)
~/.tor-suite/start_tor.sh
```

## Verify

```
curl --socks5 localhost:9150 https://check.torproject.org/api/ip
```

## Kill it

```
sudo systemctl stop tor-custom.service
sudo rm /etc/systemd/system/tor-custom.service
rm -rf ~/.tor-suite
```

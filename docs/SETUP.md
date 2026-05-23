# Ritme Handleiding Setup

## DNS Instellingen (Namecheap)

### Voor ritme.plusly.im:
```
Type: A
Host: ritme
Value: 38.124.152.103
TTL: Automatic
```

### Voor help.plusly.im:
```
Type: A
Host: help
Value: 38.124.152.103
TTL: Automatic
```

## Server Configuratie

### 1. Nginx Configuratie

Maak een nieuwe config file aan:
```bash
sudo nano /etc/nginx/sites-available/ritme.plusly.im
```

Inhoud:
```nginx
server {
    listen 80;
    server_name ritme.plusly.im help.plusly.im;
    
    root /var/www/ritme.plusly.im;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # PDF handleiding
    location /handleiding {
        alias /var/www/ritme.plusly.im/docs;
        autoindex on;
    }
}
```

### 2. Activeer de site
```bash
sudo ln -s /etc/nginx/sites-available/ritme.plusly.im /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 3. SSL Certificaat (Let's Encrypt)
```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d ritme.plusly.im -d help.plusly.im
```

### 4. Upload de handleiding
```bash
mkdir -p /var/www/ritme.plusly.im/docs
# Upload de PDF en HTML bestanden hierheen
```

## Bestanden die geüpload moeten worden:
- `gebruikershandleiding.pdf`
- `interactieve-handleiding.html`
- `interactieve-handleiding.pdf`

## URLs:
- https://ritme.plusly.im/handleiding/gebruikershandleiding.pdf
- https://ritme.plusly.im/handleiding/interactieve-handleiding.html
- https://help.plusly.im (redirect naar handleiding)

## Test:
```bash
curl -I https://ritme.plusly.im/handleiding/gebruikershandleiding.pdf
```
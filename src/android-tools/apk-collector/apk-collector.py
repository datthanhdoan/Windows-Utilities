!pip install -q requests google-play-scraper beautifulsoup4

import requests
from bs4 import BeautifulSoup
from google_play_scraper import app
import os
import random
import time
import re

PROXIES = [
    "http://proxy1.example.com:8080",
    "http://proxy2.example.com:8080"
]

def get_apkmirror_download_link(package_name, version):
    """Phiên bản mới cải tiến cho APKMirror"""
    base_url = f"https://www.apkmirror.com/apk/{package_name.replace('.', '-')}"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1'
    }
    
    # Thử 3 phương pháp khác nhau
    search_patterns = [
        f"{base_url}-{version.replace('.', '-')}-release/",
        f"{base_url}-{version}-android-apk-download/",
        f"{base_url}/versions/"
    ]
    
    for url in search_patterns:
        try:
            response = requests.get(url, headers=headers)
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Phương pháp 1: Tìm nút download chính
            direct_download = soup.find('a', {'data-google-vignette': 'false'}, href=re.compile('/apk/.*download/'))
            if direct_download:
                return f"https://www.apkmirror.com{direct_download['href']}"
            
            # Phương pháp 2: Tìm trong bảng phiên bản
            version_row = soup.find('div', class_='appRow', string=re.compile(f'^{re.escape(version)}$'))
            if version_row:
                return f"https://www.apkmirror.com{version_row.find('a', class_='accent_color')['href']}"
            
            # Phương pháp 3: Tìm qua popup download
            download_form = soup.find('form', {'id': 'file_form'})
            if download_form:
                return f"https://www.apkmirror.com{download_form['action']}"
                
        except Exception as e:
            print(f"Thử phương pháp {url} không thành công: {str(e)}")
            time.sleep(2)
    
    raise Exception("Đã thử tất cả phương pháp nhưng không tìm thấy link download")

def download_apk_with_progress(url, filename):
    """Cập nhật hàm download với headers mới"""
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://apkpure.com/',
        'Origin': 'https://apkpure.com'
    }
    
    with requests.get(url, headers=headers, stream=True) as r:
        r.raise_for_status()
        total_size = int(r.headers.get('content-length', 0))
        downloaded = 0
        
        with open(filename, 'wb') as f:
            for chunk in r.iter_content(chunk_size=1024*1024):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    print(f"\rĐang tải: {downloaded/1024/1024:.2f}MB / {total_size/1024/1024:.2f}MB", end='')
    
    print(f"\n✅ Đã lưu: {filename}")

def google_play_auth():
    """Xác thực mới với Google Play API"""
    try:
        auth_url = "https://android.clients.google.com/auth"
        payload = {
            "Email": "77866214253@google.com",  # Tài khoản dummy
            "service": "oauth2:https://www.googleapis.com/auth/androidmarket",
            "token_request_options": "CAA4AQ==",
            "client_sig": "38918a453d07199354f8b19af05ec6562ced5788",
            "androidId": "3422750445442333222",
            "app": "com.android.vending",
            "device_country": "us",
            "operatorCountry": "us",
            "lang": "en_US"
        }
        headers = {
            "User-Agent": "GoogleAuth/1.4 (mako JDQ39E)",
            "Content-Type": "application/x-www-form-urlencoded"
        }
        response = requests.post(auth_url, data=payload, headers=headers)
        if "Token" not in response.text:
            raise Exception(f"Lỗi xác thực: {response.text}")
        return response.text.split("Token=")[1].split("\n")[0]
    except Exception as e:
        raise Exception(f"Không thể xác thực: {str(e)}")

def get_google_play_download(package_name, version):
    """Thử tải trực tiếp từ Google Play"""
    try:
        token = google_play_auth()
        download_url = f"https://android.clients.google.com/fdfe/download?doc={package_name}&vc={version}"
        headers = {
            "Authorization": f"GoogleLogin auth={token}",
            "User-Agent": "Android-Finsky/22.15.14 (api=3,versionCode=82151400,sdk=22,device=bullhead,hardware=bullhead,product=bullhead)",
        }
        
        # Kiểm tra link download
        response = requests.head(download_url, headers=headers, allow_redirects=True)
        if response.status_code != 200:
            raise Exception("Link download không khả dụng")
            
        return response.url  # Trả về URL redirect cuối cùng
    except Exception as e:
        raise Exception(f"Không thể tải từ Google Play: {str(e)}")

def get_apk_download_link(package_name, version):
    """Kết hợp 3 nguồn tải APK"""
    sources = [
        {"name": "APKMirror", "function": get_apkmirror_download_link},
        {"name": "APKPure", "function": get_apkpure_link},
        {"name": "APKCombo", "function": get_apkcombo_link}
    ]
    
    for source in sources:
        try:
            print(f"\n🔎 Đang thử tải từ {source['name']}...")
            url = source['function'](package_name, version)
            if url:
                print(f"✅ Tìm thấy link tại {source['name']}")
                return url
        except Exception as e:
            print(f"⚠️ {source['name']} lỗi: {str(e)}")
            time.sleep(2)
    
    raise Exception("Đã thử tất cả nguồn nhưng không tìm thấy APK phù hợp")

def get_apkpure_link(package_name, version):
    """Phiên bản hoàn chỉnh với trình duyệt ảo"""
    session = requests.Session()
    base_url = f"https://apkpure.com/{package_name.replace('.', '-')}"
    
    # Cấu hình headers giả lập Chrome mới nhất
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://apkpure.com/',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'TE': 'trailers'
    }

    try:
        # Bước 1: Truy cập trang download
        download_page = session.get(f"{base_url}/download", headers=headers)
        download_page.raise_for_status()
        
        # Bước 2: Phân tích cấu trúc trang
        soup = BeautifulSoup(download_page.text, 'html.parser')
        
        # Bước 3: Lấy thông tin bảo mật
        token = soup.find('input', {'name': 'token'})['value']
        timestamp = soup.find('input', {'name': 't'})['value']
        
        # Bước 4: Tạo URL download hợp lệ
        download_url = f"https://apkpure.com/download.php?package={package_name}&t={timestamp}&token={token}"
        
        # Bước 5: Gửi request download
        response = session.get(download_url, headers=headers, allow_redirects=True)
        
        # Bước 6: Lấy link thực từ iframe
        soup = BeautifulSoup(response.text, 'html.parser')
        iframe = soup.find('iframe', id='iframe_download')
        if not iframe:
            raise Exception("Không tìm thấy iframe download")
            
        final_url = iframe['src'] if iframe['src'].startswith('http') else f"https:{iframe['src']}"
        final_url += "&force=1" if "?" in final_url else "?force=1"
        
        return final_url.replace('/APK/', '/XAPK/') + "&arch=arm64-v8a"
        
    except Exception as e:
        print(f"APKPure error: {str(e)}")
        # Fallback có kiểm tra phiên bản
        return f"https://d.apkpure.com/b/XAPK/{package_name}?version={version}&force=1"

def get_apkcombo_link(package_name, version):
    """Tải từ APKCombo sử dụng API public"""
    api_url = f"https://apkcombo.com/api/v1/app"
    params = {
        "package": package_name,
        "lang": "en",
        "device": "",
        "android": "",
        "cc": "US",
        "av": version
    }
    
    response = requests.get(api_url, params=params)
    if response.status_code == 200:
        data = response.json()
        if data.get('url'):
            return data['url']['web']
    
    raise Exception("APKCombo: Phiên bản không tồn tại")

def main(package_name):
    try:
        # Lấy thông tin ứng dụng
        app_info = app(package_name)
        version = app_info['version']
        
        # Tải từ nhiều nguồn
        download_url = get_apk_download_link(package_name, version)
        
        # Tiến hành tải
        filename = f"{package_name}_v{version.replace('.', '_')}.apk"
        download_apk_with_progress(download_url, filename)

    except Exception as e:
        print(f"\n❌ Lỗi: {str(e)}")
        print("👉 Hướng dẫn thủ công:")
        print(f"1. Truy cập APKPure: https://apkpure.com/{package_name}")
        print(f"2. Hoặc APKMirror: https://www.apkmirror.com/apk/{package_name.replace('.', '-')}")
        print(f"3. Tìm phiên bản {version} và tải thủ công")

# Cấu hình package name tại đây
PACKAGE_NAME = "com.color.busfrenzy"  # Thay đổi package name cần tải

if __name__ == "__main__":
    main(PACKAGE_NAME)
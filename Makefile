.PHONY: dep get-nginx get-ssl build-ssl

compile_process = 4

group = nginx
user = nginx

base_pass = $(PWD)
lib_path = lib

nginx = nginx-1.18.0
nginx_path = $(lib_path)/$(nginx)
nginx_url = http://nginx.org/download/nginx-1.18.0.tar.gz
nginx_file = lib/nginx.tar.gz

zlib = zlib-1.2.11
zlib_url = http://zlib.net/zlib-1.2.11.tar.gz
zlib_file = lib/zlib.tar.gz

pcre = pcre-8.43
pcre_url = https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz
pcre_file = lib/pcre-8.44.tar.gz

boringssl = boringssl
ssl_lib = $(boringssl)/.openssl/lib
ssl_include = $(boringssl)/.openssl/include/openssl

clean:
	cd $(lib_path); \
	rm -rf $(nginx_file) $(nginx) $(boringssl) $(zlib) $(pcre)

dep: get-nginx get-ssl get-zlib get-pcre
get-nginx:
	curl $(nginx_url) -o $(nginx_file)
	tar zxf $(nginx_file) -C lib
	rm $(nginx_file)

get-ssl:
	git clone --depth 1 https://github.com/google/boringssl.git $(lib_path)/$(boringssl)

get-zlib:
	curl $(zlib_url) -o $(zlib_file)
	tar zxf $(zlib_file) -C lib
	rm $(zlib_file)

get-pcre:
	curl $(pcre_url) -o $(pcre_file)
	tar zxf $(pcre_file) -C lib
	rm $(pcre_file)

build-ssl:
	cd $(lib_path)/$(boringssl) && \
		mkdir -p build .openssl/{lib,include}
	cd $(lib_path)/$(boringssl) && \
		ln -sf `pwd`/include/openssl .openssl/include/ \
		# && touch .openssl/include/openssl/ssl.h
	cd $(lib_path)/$(boringssl) && cmake -S ./ -B build/ -DCMAKE_BUILD_TYPE=Release
	cd $(lib_path)/$(boringssl) && make -C build/ -j $(compile_process)
	cd $(lib_path)/$(boringssl) && \
		cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib

build: 
	cd $(nginx_path) && \
	./configure \
		--prefix=/opt/nginx \
		--sbin-path=/usr/sbin/nginx \
		--user=nginx --group=nginx \
		--modules-path=/usr/lib64/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--with-cc-opt="-static -O2" \
		--with-ld-opt="-static" \
		--with-file-aio \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-http_auth_request_module \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-pcre=../$(pcre) --with-pcre-jit \
		--with-zlib=../$(zlib) \
		--with-openssl=../$(boringssl)
	touch $(lib_path)/$(boringssl)/include/openssl/ssl.h
	cd $(nginx_path) && \
		make -j $(compile_process)

install: build
	$(MAKE) -C $(nginx_path) install

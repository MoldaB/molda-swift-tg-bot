From swift
WORKDIR /app
COPY . ./
CMD swift package clean
CMD swift package resolve
CMD swift run
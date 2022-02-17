# FROM python:3.7-alpine
FROM registry.redhat.io/rhel8/python-39:1-27
COPY . /app
WORKDIR /app
RUN pip install .
CMD ["project_name"]

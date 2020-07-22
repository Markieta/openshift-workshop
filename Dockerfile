FROM python:3.7.1-alpine3.8

ENV CUSTOM_VAR Dockerfile_Override

ADD app.py /

RUN pip install flask

EXPOSE 5000

CMD [ "python", "app.py" ]

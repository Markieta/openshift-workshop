FROM python:3.7.1-alpine3.8

ADD app.py /

RUN pip install flask

CMD [ "python", "app.py" ]
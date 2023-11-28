FROM nginx:1.18
RUN ls -lh .

ENTRYPOINT ["python", "failure2.py"]
FROM haskell:9.4

WORKDIR /app

COPY . .

RUN cabal update
RUN cabal build

EXPOSE 3000

CMD ["cabal", "run", "zlogs"]
FROM mambaorg/micromamba:0.19.1
USER root
RUN apt update
RUN apt install -y git
USER mambauser
RUN git clone https://github.com/autorope/donkeycar
WORKDIR donkeycar
RUN micromamba env create --yes -f install/envs/ubuntu.yml -c conda-forge
ENV ENV_NAME=donkey
ENV MAMBA_DOCKERFILE_ACTIVATE=1
RUN pip install -e .[pc]
RUN donkey createcar --path ~/car
WORKDIR /home/mambauser/car
CMD /bin/bash
CMD bash -c 'python3 train.py --tubs ~/data --model models/model.h5'

# TODO: cuda, use multistage docker and the cuda image to train on the gpu
# idea: make the car, copy the data, then begin new stage on nvidia, copy
# the car then train (will most likely break bc dependencies).

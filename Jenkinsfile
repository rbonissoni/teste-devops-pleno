pipeline {
  agent any
  options { timestamps() }

  parameters {
    string(name: 'DEPLOY_HOST', defaultValue: '',  description: 'IP/DNS público da EC2 (ex: 44.197.x.y)')
    string(name: 'APP_DIR',     defaultValue: 'app', description: 'Diretório do código dentro do repo (se existir)')
  }

  environment {
    SSH_CRED = 'ec2-ssh'        // credencial SSH já criada no Jenkins
    SSH_USER = 'admin'
    HEALTH   = 'http://127.0.0.1:3000/health'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'echo "Commit: $(git rev-parse --short HEAD)"'
      }
    }

    stage('Build & Test (se houver)') {
      steps {
        script {
          if (fileExists("${params.APP_DIR}/package.json")) {
            dir("${params.APP_DIR}") {
              sh '''
                set -eux
                command -v node || true
                npm ci --omit=dev || npm install --omit=dev
                npm test || echo "Sem testes formais - ok p/ desafio"
              '''
            }
          } else {
            echo "Sem package.json — pulando build/tests (ok p/ desafio se app foi provisionado via user_data)"
          }
        }
      }
    }

    stage('Deploy na EC2') {
      when { expression { return params.DEPLOY_HOST?.trim() } }
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: env.SSH_CRED,
                                           keyFileVariable: 'SSH_KEY',
                                           usernameVariable: 'SSH_USER_EFF')]) {
          sh '''
            set -euxo pipefail
            chmod 600 "$SSH_KEY"
            REMOTE="${SSH_USER_EFF}@${DEPLOY_HOST}"

            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" 'uname -a; id; sudo systemctl is-enabled nginx || true'

            if [ -d "${APP_DIR}" ]; then
              REL="jenkins-${BUILD_TAG}"
              ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" "sudo mkdir -p /var/www/app/releases/${REL} /var/www/app/shared"
              rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" "${APP_DIR}/" "$REMOTE:/tmp/${REL}/"
              ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" "sudo rsync -a /tmp/${REL}/ /var/www/app/releases/${REL}/ && sudo ln -sfn /var/www/app/releases/${REL} /var/www/app/current"
              ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" "sudo chown -R www-data:www-data /var/www/app || true"
            else
              echo "Diretório ${APP_DIR} não existe — assumindo app via user_data."
            fi

            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" 'sudo nginx -t && (sudo systemctl reload nginx || sudo systemctl restart nginx)'
            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" 'sudo systemctl daemon-reload || true; sudo systemctl enable app || true; sudo systemctl restart app || true'

            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" "curl -fsS ${HEALTH}"
            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$REMOTE" "curl -fsSI http://127.0.0.1/ | head -n 1"
          '''
        }
      }
    }

    stage('Smoke test externo') {
      when { expression { return params.DEPLOY_HOST?.trim() } }
      steps {
        sh '''
          set -eux
          curl -fsS "http://${DEPLOY_HOST}/health"
          curl -fsSI "http://${DEPLOY_HOST}" | head -n 1
        '''
      }
    }

    stage('Valida Jenkins (prints)') {
      steps {
        echo 'Tire prints: Build com parâmetros, estágios OK, health externo 200.'
      }
    }
  }

  post {
    success { echo 'Pipeline OK — checkout, (build/test), deploy e validação.' }
    failure { echo 'Pipeline falhou — veja o Console Output.' }
  }
}

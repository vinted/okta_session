pipeline {
    agent { label 'slave' }
    environment {
        NEXUS_CREDENTIALS = credentials('nexus_backend_user')
        GIT_CREDENTIALS = credentials('github-jenkins-user')
        NEXUS_REPO_URL = 'https://nexus.vinted.net/repository/rubygems-hosted-backend'
    }
    options {
        ansiColor('xterm')
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(
            logRotator(
                daysToKeepStr: '60',
                numToKeepStr: '300',
                artifactDaysToKeepStr: '5',
                artifactNumToKeepStr: '20'
            )
        )
    }
    stages {
        stage('Setup & Release') {
          agent {
              docker {
                  image 'ruby:2.7'
                  args '-e BUNDLE_PATH=$WORKSPACE -e HOME=$WORKSPACE'
              }
          }
          stages {
            stage('Setup') {
                steps {
                    sh 'gem install bundler:1.17.3'
                    sh 'bundle install'
                }
            }
            stage('Build') {
                when {
                    branch 'master'
                }
                steps {
                    sh 'rm pkg/* || true'
                    sh 'bundle exec rake build'
                }
            }
            stage('Release') {
                when {
                    branch 'master'
                }
                steps {
                    sh 'gem install nexus'
                    sh 'gem nexus --url $NEXUS_REPO_URL --credential $NEXUS_CREDENTIALS pkg/*'
                }
                post {
                    failure {
                        script {
                            currentBuild.result='UNSTABLE'
                        }
                        error('Gem release to nexus failed.')
                    }
                }
            }
          }
        }
        stage('Tag release') {
            when {
                branch 'master'
            }
            steps {
                sh '''
                    TAG=$(cat ./lib/version.rb | grep VERSION | sed "s/'//g" | awk '{ print "v"$3 }')
                    ORIGIN=$(echo $GIT_URL | sed 's+https://+https://'$GIT_CREDENTIALS'@+g')
                    git tag -f $TAG
                    git push $ORIGIN --tags
                '''
            }
        }
    }
}

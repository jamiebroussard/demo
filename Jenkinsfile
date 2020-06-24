#!/usr/bin/groovy
// Author:
// Jamie Broussard jamie@jamiebroussard.com

// import shared functions
@Library('jbroussard-shared') _  // Import Jenkins Global Library

pipeline {
  agent any
  environment {
    service_name    = "hello-world-spring-boot"
    dev_branch      = "development"
    rel_branch      = "release"
    yamlfile        = "${service_name}.yaml"
    app_version     = readFile('version.txt').trim()
    build_id        = "${BUILD_NUMBER}" // Jenkins build ID
    dev_version     = "${app_version}.${build_id}"
    release_version = "${app_version}.r${build_id}"
    docker_context  = "${WORKSPACE}"
    dockerfile      = "Dockerfile"
    build_notify    = "${project.build_notify}"
    docker_repo     = "${project.dev_aws_account}.dkr.ecr.${project.dev_region}.amazonaws.com"
    docker_url      = "https://${docker_repo}"
  }
  // START THE PIPELINE
  stages {
    // All branches get built and scanned
    stage ('Build') {
      steps {
        // Build
        sh "mvn clean install"
      }
    }
    stage ('Create Dev Image') {
      when{
        expression {env.GIT_BRANCH == "${dev_branch}"}
      }
      environment {
        region      = "${project.dev_region}"
        docker_repo = "${project.dev_aws_account}.dkr.ecr.${project.dev_region}.amazonaws.com"
        docker_url  = "https://${docker_repo}"
        profile     = "${project.dev_profile}"
      }
      steps {
        script {
          // Clean up
          // TODO in some environments this will break things
          container.rmDanglingContainers()
          container.rmDanglingImages()
          container.rmDanglingVolumes()
          // Login to image repo
          aws.ecrLogin2(project.dev_region, project.dev_profile)
          // build the image
          container.build_push("$docker_url", "$service_name", "$dev_version")
        }
      }
    }
    stage ('Deploy to Dev') {
      when{
        branch "${dev_branch}"
      }
      environment {
        docker_repo       = "${project.dev_aws_account}.dkr.ecr.${project.dev_region}.amazonaws.com"
        environment       = "dev"
        deployment_image  = "${docker_repo}\\/${service_name}:${dev_version}"
        env_yaml          = "${service_name}.${environment}.yaml"
      }
      steps {
        script {
          // replace image name with sed on new yaml for this env
          utility.sedYaml(
            "$yamlfile",
            "$env_yaml",
            "$deployment_image",
            "$environment"
          )
          // deploy
          container.deploy_dev("$env_yaml", "k8")
          // Sanity test
          test.devSanityTest()
        }
      }
    }
    stage ('Create Release Images') {
      when{
        branch "${rel_branch}"
      }
      environment {
        // DEV
        dev_region        = "${project.dev_region}"
        dev_docker_repo   = "${project.dev_aws_account}.dkr.ecr.${project.dev_region}.amazonaws.com"
        dev_profile       = "${project.dev_profile}"
        dev_docker_url    = "https://${project.dev_aws_account}.dkr.ecr.${project.dev_region}.amazonaws.com"
        //PROD useast
        prod_region       = "${project.prod_region}"
        prod_docker_repo  = "${project.prod_aws_account}.dkr.ecr.${project.prod_region}.amazonaws.com"
        prod_profile      = "${project.prod_profile}"
        prod_docker_url    = "https://${project.prod_aws_account}.dkr.ecr.${project.prod_region}.amazonaws.com"
      }
      steps {
        script {
          // Clean up
          container.rmDanglingContainers()
          container.rmDanglingImages()
          container.rmDanglingVolumes()
          // Login to image repo
          aws.ecrLogin2("$dev_region", "$dev_profile")
          // build the image for QA
          container.build_push("$dev_docker_url", "$service_name", "$release_version")
          // Scan image
          test.imageSecScan()
          // Login to image repo for prod account
          aws.ecrLogin2("$prod_region", "$prod_profile")
          aws.ecrCreateRepo2("$service_name", "$prod_region", "$prod_profile")
          // build the image for Stage and prod
          container.build_push("$prod_docker_url", "$service_name", "$release_version")
          // Scan image
          test.imageSecScan()
        }
      }
    } //Create Release Images
    stage ("Deploy to Prod") {
      when{
        branch "${rel_branch}"
      }
      environment {
        environment       = "prod"
        docker_repo       = "${project.prod_aws_account}.dkr.ecr.${project.prod_region}.amazonaws.com"
        deployment_image  = "${docker_repo}\\/${service_name}:${release_version}"
        env_yaml          = "${service_name}.${environment}.yaml"
      }
      steps {
        script {
          input message: 'Deploy to Prod? (Click "Proceed" to continue)'
          // replace image name with sed on new yaml for this env
          utility.sedYaml(
            "$yamlfile",
            "$env_yaml",
            "$deployment_image",
            "$environment"
          )
          // deploy
          container.deploy_old_prod("$env_yaml")
          container.deploy_prod("$env_yaml")
          // Sanity test
          test.prodSanityTest()
          input message: 'Finished using the web site? (Click "Proceed" to continue)'
        }
      }
    } //Deploy to prod
    stage ("Notify") {
      steps {
        script {
          notify.emailext("$project.build_notify")
        }
      }
    }
  }// stages
  post {
    always {
      echo 'One way or another, I have finished'
      deleteDir() /* clean up our workspace */
    }
    success {
      echo 'I succeeeded!'
    }
    unstable {
      echo 'I am unstable :/'
    }
    failure {
      echo 'I failed :('
    }
    changed {
      echo 'Things were different before...'
    }
  }//post
}

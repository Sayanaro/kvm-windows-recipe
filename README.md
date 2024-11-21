# Подготовка собственных образов с продуктами Microsoft для использования в облаках на базе QEMU/KVM

> ### ⚠ Внимание!
> Инструкция и скрипты подготовки образов Windows Server распространяются As-Is и не предполагают расширенной поддержки. Рецепт подготовлен и протестирован на GVLK образах Windows Server 2016, 2019 и 2022 в облаках на базе QEMU/KVM. Иные версии, сборки, а также клиентские образы не поддержаны. Используя данный рецепт, вы соглашаетесь с тем, что неподдержанные сценарии вы должны добавить самостоятельно. Таже, пользователь рецепта принимает на себя все риски и вопросы, связанные с политикой лицензирования Microsoft. Разработчик и сервис-провайдеры не несет ответственности за недобросовестное использование данной инструкции.

> ### ⚠ Внимание!
> Для подготовки образов понадобится ISO-образ GVLK, который доступен на официально портале Microsoft Software Assurance. Сторонние сборки ISO-образов не поддерживаются данным рецептом.

## Definition of done
Рецепт принимает на вход GVLK образ Windows Server, проводит настройку системы и устанавливает:
- Cloudbase-Init
- Последнее куммулятивное обновление + обновления .NET Framework 4.x + обновления безопасности
- Windows Features: .NET Framework 3.5, Telnet Client, Windows Backup

После чего система переходит в OOBE и ВМ выключается. Полученный образ можно использовать для развертывания виртуальных машин в Yandex Cloud.

## Подготовка образа MacOS/Linux

Чтобы создать образ, готовый к использованию в yandex-cloud:

1. [Установите QEMU](https://www.qemu.org/download/).
2. [Установите Packer](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/packer-quickstart#install-packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli).
3. Загрузите архив с [конфигурациями для Packer](download/public-windows-packer-v2.zip) и распакуйте его в нужную папку, например `windows-packer`.
4. Загрузите [образ с драйверами](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) и откройте его. Переместите папки `NetKVM`, `vioserial` и `viostor` в папку `windows-packer/drivers`. Папки содержат драйверы для разных ОС — обязательно используйте драйверы для вашей.
5. Выберите подходящую для вашего продукта Microsoft конфигурацию для Packer и внесите следующие изменения в ее конфигурационный файл:

   5.1. Укажите в параметре `iso_url` путь к вашему дистрибутиву. 

   5.2. В блоке `cd_files` укажите пути к распакованным драйверам для вашей версии ОС, например:

      ```
      cd_files = [
          "../drivers/NetKVM/2k19/amd64/*",
          "../drivers/viostor/2k19/amd64/*",
          "../drivers/vioserial/2k19/amd64/*",
          "../scripts/qemu/*",
          "Autounattend.xml"
        ]
      ```

      Обратите внимание, что Packer чувствителен к регистру. Если вы поместили папки с драйверами в другое место, укажите соответствующие пути.
      
   5.3. Узнайте контрольную сумму вашего дистрибутива (например, выполните `openssl dgst -sha256 <путь к дистрибутиву>`). Вставьте полученное значение в параметр `iso_checksum` после `sha256:`.

   5.4. (Опционально) Если вы работаете на MacOS, вам потребуется заменить значение `accelerator  = "kvm"` на `accelerator  = "hvf"`.
   
6. Перейдите в каталог с нужной конфигурацией образа (например, `public-windows-packer/ws22gui-qemu`) и выполните команду `packer build .`. 

## Подготовка образа Windows 10/11

1. [Установите QEMU](https://www.qemu.org/download/#windows)
2. Пропишите в переменные Windows путь к файлам QEMU (например `set PATH=C:\Program Files\QEMU\`)
3. [Установите Packer из зеркала](https://hashicorp-releases.yandexcloud.net/packer/)
4. Установите Packer в `C:\Program Files\Packer\`
5. Пропишите в переменные Windows путь к файлам Packer (например `set PATH=C:\Program Files\Packer\`)
6. Создайте в директории `C:\Program Files\Packer\` файл с именем `config.pkr.hcl` и добавте в него код:
```hcl
packer {
  required_plugins {
    yandex = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/yandex"
    }
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}  
```    
9. Запустите в коммандной строке packer `init config.pkr.hcl` или запустите команду `packer plugins install github.com/hashicorp/qemu`
10. [Скачайте **Windows ADK** последней версии](https://learn.microsoft.com/ru-ru/windows-hardware/get-started/adk-install)
11. Установите **Windows ADK**, выбрав только один компонент - `Deployment Tools`
12. Пропишите в переменные Windows путь к файлу `Oscdimg.exe` (`C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\`)
13. Установите роль Hyper-V:
```PowerSHell
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools
```

14. Далее проверьте важные параметры:
    14.1. Ваши файлы скриптов и Packer должны иметь EOL соответствующий Windows (CRLF)

    14.2. В файле сценария должен быть указан аккселератор `WHPX` (`accelerator  = "WPHX"`)

    14.3. Для использования WHPX у вас должна быть установлена роль Hyper-V

    14.4. Для корректной работы параметр `smp` в файле сценария Packer должен быть установлен в 1, большие значения могут приводить к значительной вероятности сбоя.
15. Узнайте контрольную сумму вашего дистрибутива: 
```PowerShell
(Get-FileHash -Path <путь к дистрибутиву> -Algorithm SHA256).Hash.ToLower()
```
Вставьте полученное значение в параметр `iso_checksum` после `sha256:`.
16. Перейдите в каталог с нужной конфигурацией образа (например, `public-windows-packer/ws22gui-qemu`) и выполните команду `packer build .`.

> ### ⚠ Примечание
> Чтобы отслеживать сборку образа и видеть ошибки, вы можете подключиться к ВМ по VNC. Например, с помощью VNC-клиента от [RealVNC](https://www.realvnc.com/en/connect/download/viewer/).


После выполнения команды будет создан дисковый образ в формате `.qcow2`.

## Загрузите образ в объектное хранилище

Загрузите созданный образ в {{ objstorage-name }} с помощью одного из [поддерживаемых инструментов](https://yandex.cloud/ru/docs/storage/tools/).

**Пример для AWS CLI:**
```bash
aws s3 --endpoint-url=https://storage.yandexcloud.net cp output/packer-ws19core s3://<bucket_name>/packer-ws19core.qemu
```

## Импортируйте образ
[Импорт образов в VK Cloud](https://cloud.vk.com/docs/computing/iaas/how-to-guides/win-image#4_importiruyte_obraz_v_oblako_vk_cloud)
[Импорт образа в Yandex Cloud](https://yandex.cloud/ru/docs/microsoft/byol#how-to-import)

Импортированный образ можно использовать при создании загрузочного диска ВМ.

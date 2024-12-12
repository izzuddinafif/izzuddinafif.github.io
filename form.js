// Fungsi untuk mengisi semua input radio dalam form dengan nilai acak
function fillRadiosRandomly() {
    // Ambil semua elemen form
    const form = document.querySelector('form');
    if (!form) {
        console.log('Form tidak ditemukan.');
        return;
    }

    // Cari semua group input radio dalam form
    const radioGroups = new Set();
    form.querySelectorAll('input[type="radio"]').forEach(radio => {
        radioGroups.add(radio.name); // Gunakan nama untuk mengelompokkan
    });

    // Iterasi setiap group radio
    radioGroups.forEach(groupName => {
        // Ambil semua radio dalam group
        const radios = form.querySelectorAll(`input[name="${groupName}"]`);
        if (radios.length > 0) {
            // Pilih nilai random antara 2 dan 4
            const randomValue = Math.floor(Math.random() * 3) + 2;

            // Pilih radio dengan value yang sesuai
            const selectedRadio = Array.from(radios).find(radio => radio.value == randomValue);
            if (selectedRadio) {
                selectedRadio.checked = true;
                console.log(`Radio di group "${groupName}" dengan value ${selectedRadio.value} telah dipilih.`);
            } else {
                console.log(`Tidak ada radio dengan value ${randomValue} di group "${groupName}".`);
            }
        }
    });
}

// Jalankan fungsi
fillRadiosRandomly();
